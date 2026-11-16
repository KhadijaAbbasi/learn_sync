import 'dart:async';

import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/constants/app_routes.dart';
import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/ai_practice.dart';
import '../../models/course_content.dart';
import '../../models/live_slide_signal.dart';
import '../../models/lecture_feedback.dart';
import '../../models/chapter_model.dart';
import '../../services/course_document_text.dart';
import '../../models/live_session_model.dart';
import '../../services/ai_practice_factory.dart';
import '../../services/ai_practice_generator.dart';
import '../../widgets/custom_button.dart';
import 'ai_practice_chrome.dart';
import 'ai_practice_results_screen.dart';

class AiPracticeScreen extends StatefulWidget {
  const AiPracticeScreen({
    super.key,
    required this.session,
    required this.courseName,
    required this.studentId,
    required this.studentName,
    this.lectureOrdinal,
    this.generator,
  });

  final LiveSessionModel session;
  final String courseName;
  final String studentId;
  final String studentName;
  /// 1-based lecture number for this session/topic; shown with the lecture name.
  final int? lectureOrdinal;
  final AiPracticeGenerator? generator;

  @override
  State<AiPracticeScreen> createState() => _AiPracticeScreenState();
}

class _AiPracticeScreenState extends State<AiPracticeScreen> {
  late final AiPracticeGenerator _generator;
  var _loading = true;
  var _submitting = false;
  String? _errorCode;
  String? _errorMessage;
  String? _taughtNotes;
  String _sourceKind = 'notes';
  List<WeakSlideFocus> _weakSlides = const [];
  String _chapterTitle = '';
  String _topicTitle = '';
  AiQuiz? _quiz;
  List<int?> _selected = List<int?>.filled(kAiPracticeQuestionCount, null);

  @override
  void initState() {
    super.initState();
    _generator = widget.generator ?? createAiPracticeGenerator();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prepare());
    });
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _errorCode = null;
      _errorMessage = null;
      _quiz = null;
    });
    try {
      if (!_generator.isSupported) {
        setState(() {
          _loading = false;
          _errorCode = AiPracticeException.unsupported;
        });
        return;
      }
      final store = AppScope.of(context).courseStore;
      final lecture = await store.watchLecture(widget.session.id).first;
      final chapterId = (lecture?.chapterId.trim().isNotEmpty == true)
          ? lecture!.chapterId.trim()
          : widget.session.chapterId.trim();
      final topicId = (lecture?.topicId.trim().isNotEmpty == true)
          ? lecture!.topicId.trim()
          : widget.session.topicId.trim();
      var chapter = (lecture?.chapterTitle.trim().isNotEmpty == true)
          ? lecture!.chapterTitle.trim()
          : widget.session.chapterTitle.trim();
      var topic = (lecture?.topicTitle.trim().isNotEmpty == true)
          ? lecture!.topicTitle.trim()
          : widget.session.topicTitle.trim();
      if ((chapter.isEmpty && chapterId.isNotEmpty) ||
          (topic.isEmpty && topicId.isNotEmpty)) {
        try {
          if (chapter.isEmpty && chapterId.isNotEmpty) {
            final chapters = await store
                .watchChapters(widget.session.courseId)
                .first;
            for (final item in chapters) {
              if (item.id == chapterId && item.title.trim().isNotEmpty) {
                chapter = item.title.trim();
                break;
              }
            }
          }
          if (topic.isEmpty && chapterId.isNotEmpty && topicId.isNotEmpty) {
            final topics = await store
                .watchTopics(widget.session.courseId, chapterId)
                .first;
            for (final item in topics) {
              if (item.id == topicId && item.title.trim().isNotEmpty) {
                topic = item.title.trim();
                break;
              }
            }
          }
        } catch (error) {
          debugPrint('AI practice title lookup failed: $error');
        }
      }
      _chapterTitle = chapter;
      _topicTitle = topic;

      // Prefer topic documents/slides; fall back to legacy taughtNotes.
      var notes = '';
      var sourceKind = 'notes';
      var attachments = const <CourseAttachment>[];
      var slideChunks = const <SlideTextChunk>[];
      if (chapterId.isNotEmpty && topicId.isNotEmpty) {
        try {
          final topics = await store
              .watchTopics(widget.session.courseId, chapterId)
              .first;
          TopicModel? matched;
          for (final item in topics) {
            if (item.id == topicId) {
              matched = item;
              break;
            }
          }
          attachments = matched?.attachments ?? const <CourseAttachment>[];
          if (attachments.isNotEmpty) {
            final docSource = await extractDocumentQuizSource(attachments);
            slideChunks = docSource.slides;
            if (!docSource.isEmpty) {
              notes = docSource.combinedText;
              sourceKind = 'documents';
            }
          }
        } catch (error, stack) {
          debugPrint('AI practice document extract failed: $error');
          debugPrint('$stack');
        }
      }
      if (notes.isEmpty) {
        notes = (await store.loadTaughtNotes(widget.session.id)).trim();
        sourceKind = 'notes';
      }

      var weak = <WeakSlideFocus>[];
      try {
        final mine = await store
            .watchStudentLiveSlideSignals(
              courseId: widget.session.courseId,
              sessionId: widget.session.id,
              studentId: widget.studentId,
            )
            .first;
        weak = _weakFocusFromSignals(
          mine,
          attachments: attachments,
          slides: slideChunks,
        );
      } catch (error) {
        debugPrint('AI practice weak-slide load failed: $error');
      }

      debugPrint(
        'AI practice source=$sourceKind lecture=${widget.session.id}: '
        '${notes.isEmpty ? "MISSING" : "${notes.length} chars"}; '
        'weakSlides=${weak.length}',
      );

      if (topic.isEmpty || notes.isEmpty) {
        setState(() {
          _loading = false;
          _taughtNotes = notes;
          _sourceKind = sourceKind;
          _weakSlides = weak;
          _errorCode = AiPracticeException.missingNotes;
          _errorMessage = topic.isEmpty
              ? 'Topic name is missing, so a practice quiz cannot be generated yet.'
              : 'Your teacher has not uploaded lecture documents (or notes) for this topic yet, so a practice quiz cannot be generated. Ask them to add slides/documents, then try again.';
        });
        return;
      }
      // Weak slides (60% or below ≈ ≤70%): quiz ONLY from those pages.
      // No weak feedback: full lecture (all slides).
      if (weak.isNotEmpty) {
        notes = textForSlideTargets(
          slides: slideChunks,
          targetKeys: {
            for (final slide in weak) '${slide.fileIndex}:${slide.slidePage}',
          },
          fallbackNotes: notes,
          // Never expand back to the full lecture when the student marked weak slides.
          allowFullFallback: false,
        );
      }
      _taughtNotes = notes;
      _sourceKind = sourceKind;
      _weakSlides = weak;
      final stampSlides = weak.isNotEmpty
          ? weak
          : _allSlidesFocus(slideChunks);

      // Fresh backend call on every open - no client-side quiz cache.
      await _generator.ensureReady();
      if (!mounted) {
        return;
      }
      final quiz = stampBelow50QuizSources(
        quiz: await _generator.generateQuiz(_request(notes)),
        chapterTitle: _chapterTitle.isNotEmpty
            ? _chapterTitle
            : widget.session.chapterTitle,
        lectureTitle: _topicTitle.isNotEmpty
            ? _topicTitle
            : widget.session.topicTitle,
        below50Slides: stampSlides,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _quiz = quiz;
        _selected = List<int?>.filled(quiz.length, null);
        _loading = false;
      });
    } on AiPracticeException catch (error) {
      debugPrint(
        'AI practice prepare failed: ${error.message.isEmpty ? error.code : error.message}',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorCode = error.code;
        _errorMessage = error.message.isEmpty ? null : error.message;
      });
    } catch (error) {
      debugPrint('AI practice prepare failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorCode = AiPracticeException.generateFailed;
        _errorMessage = error.toString();
      });
    }
  }

  AiQuizRequest _request(String notes) {
    return AiQuizRequest(
      taughtNotes: notes,
      topicTitle: _topicTitle.isNotEmpty
          ? _topicTitle
          : widget.session.topicTitle,
      chapterTitle: _chapterTitle.isNotEmpty
          ? _chapterTitle
          : widget.session.chapterTitle,
      courseName: widget.courseName,
      weakSlides: _weakSlides,
      sourceKind: _sourceKind,
    );
  }

  /// Slides the student marked ≤70% (60% need recap, or Below 50% need help).
  List<WeakSlideFocus> _weakFocusFromSignals(
    List<LiveSlideSignal> mine, {
    required List<CourseAttachment> attachments,
    required List<SlideTextChunk> slides,
  }) {
    final out = <WeakSlideFocus>[];
    final seen = <String>{};
    for (final signal in mine) {
      // Keep only weak understanding: 60% and below-50 (not 80% / 100%).
      final isWeak = signal.level == UnderstandingLevel.percent60 ||
          signal.level == UnderstandingLevel.below50;
      if (!isWeak) {
        continue;
      }
      final fileIndex = signal.slideFileIndex;
      final page = signal.slidePage < 1 ? 1 : signal.slidePage;
      final key = '$fileIndex:$page';
      if (!seen.add(key)) {
        continue;
      }
      var fileName = '';
      if (fileIndex >= 0 && fileIndex < attachments.length) {
        fileName = attachments[fileIndex].name.trim();
      }
      if (fileName.isEmpty) {
        for (final slide in slides) {
          if (slide.fileIndex == fileIndex &&
              slide.slidePage == page &&
              slide.fileName.trim().isNotEmpty) {
            fileName = slide.fileName.trim();
            break;
          }
        }
      }
      final isBelow50 = signal.level == UnderstandingLevel.below50;
      out.add(
        WeakSlideFocus(
          fileIndex: fileIndex,
          slidePage: page,
          fileName: fileName,
          levelLabel: isBelow50
              ? 'Below 50% (need help)'
              : '60% (need a recap)',
          priority: isBelow50 ? 3 : 2,
        ),
      );
    }
    out.sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      if (byPriority != 0) {
        return byPriority;
      }
      final byFile = a.fileIndex.compareTo(b.fileIndex);
      if (byFile != 0) {
        return byFile;
      }
      return a.slidePage.compareTo(b.slidePage);
    });
    return out;
  }

  /// All lecture slides for UI source labels when nothing is ≤70% weak.
  List<WeakSlideFocus> _allSlidesFocus(List<SlideTextChunk> slides) {
    final out = <WeakSlideFocus>[];
    for (final slide in slides) {
      out.add(
        WeakSlideFocus(
          fileIndex: slide.fileIndex,
          slidePage: slide.slidePage > 0 ? slide.slidePage : 1,
          fileName: slide.fileName.trim(),
          levelLabel: 'Lecture slide',
          priority: 0,
        ),
      );
    }
    return out;
  }

  void _goHome() {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.studentDashboard, (_) => false);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final quiz = _quiz;
    if (quiz == null || _submitting) {
      return;
    }
    if (_selected.any((item) => item == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.aiPracticeSubmitIncomplete)));
      return;
    }
    final store = AppScope.of(context).courseStore;
    setState(() => _submitting = true);
    final selected = [for (final item in _selected) item!];
    final score = scoreQuiz(quiz, selected);
    var diagnostic = '';
    try {
      diagnostic = await _generator.generateDiagnostic(
        request: _request(_taughtNotes ?? ''),
        quiz: quiz,
        selectedIndexes: selected,
        score: score,
      );
    } catch (error) {
      debugPrint('AI diagnostic failed: $error');
    }
    final attempt = AiPracticeAttempt(
      id: '',
      lectureId: widget.session.id,
      courseId: widget.session.courseId,
      courseName: widget.courseName,
      teacherId: widget.session.teacherId,
      studentId: widget.studentId,
      studentName: widget.studentName,
      topicTitle: _topicTitle.isNotEmpty
          ? _topicTitle
          : widget.session.topicTitle,
      chapterTitle: _chapterTitle.isNotEmpty
          ? _chapterTitle
          : widget.session.chapterTitle,
      score: score,
      total: quiz.length,
      selectedIndexes: selected,
      diagnostic: diagnostic,
      questions: quiz.questions,
    );
    try {
      final saved = await store.savePracticeAttempt(attempt: attempt);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AiPracticeResultsScreen(
            session: widget.session,
            courseName: widget.courseName,
            studentId: widget.studentId,
            studentName: widget.studentName,
            attempt: saved,
            lectureOrdinal: widget.lectureOrdinal,
            generator: _generator,
          ),
        ),
      );
    } catch (error) {
      debugPrint('savePracticeAttempt failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.aiPracticeSaveFailed)));
        setState(() => _submitting = false);
      }
    }
  }

  String _named(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '—' : trimmed;
  }

  /// Chapter stored on the lecture, or the live session.
  String get _displayChapter {
    if (_chapterTitle.trim().isNotEmpty) {
      return _chapterTitle.trim();
    }
    return widget.session.chapterTitle.trim();
  }

  /// This app names a lecture by the topic that was taught.
  String get _displayLecture {
    if (_topicTitle.trim().isNotEmpty) {
      return _topicTitle.trim();
    }
    if (widget.session.topicTitle.trim().isNotEmpty) {
      return widget.session.topicTitle.trim();
    }
    return widget.courseName.trim();
  }

  String get _displayTopic => _displayLecture;

  String _slideLabelFor(int index) {
    final quiz = _quiz;
    if (quiz == null || index < 0 || index >= quiz.questions.length) {
      return '';
    }
    // Always the real slidePage stamped on the question — never Q1/Q2/Q3 order.
    final page = quiz.questions[index].slidePage;
    return page > 0 ? '$page' : '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final padding = AppResponsive.pagePadding(context);

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.pageWash,
      body: Column(
        children: [
          AiPracticeAppBar(
            title: l10n.aiPracticeScreenTitle,
            badge: l10n.inProgressStatus,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(child: _body(l10n, brightness, padding)),
          if (_quiz != null)
            Material(
              color: AppColors.fieldFill(brightness),
              elevation: 8,
              shadowColor: AppColors.navy.withValues(alpha: 0.12),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: CustomButton(
                    label: l10n.submitQuiz,
                    onPressed: _submit,
                    isLoading: _submitting,
                    variant: AppButtonVariant.signup,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(AppLocalizations l10n, Brightness brightness, double padding) {
    if (_errorCode == AiPracticeException.unsupported) {
      return _MessageState(
        icon: Icons.phonelink_erase_rounded,
        title: l10n.aiPracticeScreenTitle,
        body: l10n.aiPracticeUnsupported,
        action: l10n.backToDashboard,
        onAction: _goHome,
      );
    }
    if (_errorCode == AiPracticeException.noBelow50) {
      return _MessageState(
        icon: Icons.fact_check_outlined,
        title: l10n.aiPracticeNoBelow50Title,
        body: l10n.aiPracticeNoBelow50,
        action: l10n.backToDashboard,
        onAction: _goHome,
      );
    }
    if (_errorCode == AiPracticeException.missingNotes) {
      final detail = (_errorMessage ?? '').trim();
      return _MessageState(
        icon: Icons.edit_note_rounded,
        title: l10n.aiPracticeNoNotesTitle,
        body: detail.isNotEmpty ? detail : l10n.aiPracticeNoNotes,
        action: l10n.backToDashboard,
        onAction: _goHome,
      );
    }
    if (_errorCode != null) {
      final detail = (_errorMessage ?? '').trim();
      return _MessageState(
        icon: Icons.error_outline_rounded,
        title: l10n.aiPracticeGenerateFailed,
        body: detail.isNotEmpty ? detail : l10n.aiPracticeGenerateFailed,
        action: l10n.aiPracticeRetry,
        onAction: _prepare,
      );
    }
    if (_loading) {
      return _MessageState(
        icon: Icons.smart_toy_outlined,
        title: l10n.aiPracticeGenerating,
        body: l10n.aiPracticeGenerating,
      );
    }
    final quiz = _quiz;
    if (quiz == null) {
      return const SizedBox.shrink();
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(padding, 18, padding, 24),
      children: [
        Text(
          l10n.aiPracticeSourceChapter(_named(_displayChapter)),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: AppColors.textPrimary(brightness),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.lectureOrdinal != null
              ? '${l10n.lectureNumber(widget.lectureOrdinal!)} · ${_named(_displayLecture)}'
              : l10n.aiPracticeSourceLecture(_named(_displayLecture)),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.textPrimary(brightness),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.aiPracticeSourceTopic(_named(_displayTopic)),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.textPrimary(brightness),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.aiPracticeAnswerAll,
          style: TextStyle(
            color: AppColors.textSecondary(brightness),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < quiz.questions.length; i++) ...[
          _QuestionCard(
            index: i,
            total: quiz.length,
            question: quiz.questions[i],
            slideLabel: _slideLabelFor(i),
            selected: _selected[i],
            onSelect: (option) => setState(() => _selected[i] = option),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.total,
    required this.question,
    required this.slideLabel,
    required this.selected,
    required this.onSelect,
  });

  final int index;
  final int total;
  final AiQuizQuestion question;
  final String slideLabel;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    const letters = ['A', 'B', 'C', 'D'];
    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.questionOfTotal(index + 1, total),
                style: const TextStyle(
                  color: AppColors.teal,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
            if (slideLabel.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.aiPracticeSourceSlide(slideLabel),
                  style: TextStyle(
                    color: AppColors.textPrimary(brightness),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              question.prompt,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                height: 1.35,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < question.options.length; i++) ...[
              _OptionTile(
                letter: letters[i],
                text: question.options[i],
                selected: selected == i,
                onTap: () => onSelect(i),
              ),
              if (i < question.options.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkBackground
          : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.teal : AppColors.border(brightness),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                '$letter.',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? AppColors.teal
                      : AppColors.textPrimary(brightness),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: AppColors.teal),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.teal),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: AppColors.textPrimary(brightness),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary(brightness),
              height: 1.4,
            ),
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 22),
            CustomButton(
              label: action!,
              onPressed: onAction,
              variant: AppButtonVariant.signup,
            ),
          ],
        ],
      ),
    );
  }
}
