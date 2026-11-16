import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learnsync/l10n/app_localizations.dart';
import 'package:pdfx/pdfx.dart';

import '../core/theme/app_colors.dart';
import '../models/course_content.dart';
import '../services/load_course_file.dart';
import '../services/presentation_to_pdf.dart';
import '../services/open_course_file.dart';
import 'office_document_view.dart';

typedef SlidePosition = ({int fileIndex, int page});

/// Live zoom/pan state. [zoom] 1.0 = page width fills the viewport;
/// [cx]/[cy] = viewport centre as a 0..1 fraction of the page.
/// [ts] = teacher client ms epoch so students can detect every update.
typedef SlideViewport = ({
  int fileIndex,
  int page,
  double zoom,
  double cx,
  double cy,
  int ts,
});

/// Book-style slides viewer. Teachers present; students can follow live.
class TopicSlidesViewer extends StatefulWidget {
  const TopicSlidesViewer({
    super.key,
    required this.attachments,
    this.courseId = '',
    this.title,
    this.isPresenter = true,
    this.followFileIndex,
    this.followPage,
    this.onSlideChanged,
    this.hideFileInLabel = false,
    this.followViewport,
    this.onViewportChanged,
  });

  final List<CourseAttachment> attachments;
  final String courseId;
  final String? title;

  /// When true, local prev/next publish via [onSlideChanged].
  final bool isPresenter;

  /// Student follow target (from live session).
  final int? followFileIndex;
  final int? followPage;

  final ValueChanged<SlidePosition>? onSlideChanged;

  /// Student/board: teacher's latest zoom/pan (applied while following).
  final SlideViewport? followViewport;

  /// Presenter: zoom/pan changes, throttled to ~150 ms.
  final ValueChanged<SlideViewport>? onViewportChanged;

  /// Live lecture: show page/name only — no "File N" in the chrome label.
  final bool hideFileInLabel;

  @override
  State<TopicSlidesViewer> createState() => _TopicSlidesViewerState();
}

class _TopicSlidesViewerState extends State<TopicSlidesViewer> {
  var _fileIndex = 0;
  var _loading = false;
  String? _error;
  Uint8List? _bytes;
  PdfControllerPinch? _pdfController;
  PdfController? _windowsPdfController;
  bool get _hasPdf => _pdfController != null || _windowsPdfController != null;
  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  void _openPdf(Uint8List bytes, int page) {
    _pdfPage = page < 1 ? 1 : page;
    final document = PdfDocument.openData(bytes);
    if (_isWindows) {
      // pdfx's texture-based pinch viewer is unavailable on Windows.
      _windowsPdfController = PdfController(
        document: document,
        initialPage: _pdfPage,
      );
    } else {
      _pdfController = PdfControllerPinch(
        document: document,
        initialPage: _pdfPage,
      );
      _listenViewport();
    }
  }

  Future<void> _goToPage(
    int page, {
    Duration duration = const Duration(milliseconds: 180),
  }) async {
    final windows = _windowsPdfController;
    if (windows != null) {
      if (duration == Duration.zero) {
        windows.jumpToPage(page);
      } else {
        await windows.animateToPage(
          page,
          duration: duration,
          curve: Curves.easeOut,
        );
      }
      return;
    }
    await _pdfController?.animateToPage(
      pageNumber: page,
      duration: duration,
      curve: Curves.easeOut,
    );
  }

  Widget? _officeViewer;
  var _pdfPage = 1;
  var _pdfPageCount = 0;
  var _openLastPdfPage = false;
  var _isOffice = false;
  Timer? _publishDebounce;
  var _suppressPublish = false;

  // Live zoom/pan sync.
  Timer? _viewportThrottle;
  SlideViewport? _lastSentViewport;
  int _lastAppliedViewportTs = 0;
  PdfControllerPinch? _listenedController;
  var _followTeacher = true;
  var _applyingRemote = false;
  var _activePointers = 0;

  /// Single-finger swipe tracking (presenter only). Cancelled on multi-touch.
  int? _swipePointer;
  Offset? _swipeStart;

  CourseAttachment? get _current {
    if (widget.attachments.isEmpty) {
      return null;
    }
    final i = _fileIndex.clamp(0, widget.attachments.length - 1);
    return widget.attachments[i];
  }

  @override
  void initState() {
    super.initState();
    if (!widget.isPresenter) {
      _fileIndex = widget.followFileIndex ?? 0;
      _pdfPage = widget.followPage ?? 1;
    }
    _loadCurrent(initialPage: widget.isPresenter ? null : widget.followPage);
  }

  @override
  void didUpdateWidget(covariant TopicSlidesViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameAttachments(oldWidget.attachments, widget.attachments) ||
        oldWidget.courseId != widget.courseId) {
      // A newly added topic appends files. Stay on the slide already open
      // when that file is still in the deck.
      if (oldWidget.courseId == widget.courseId &&
          _fileIndex >= 0 &&
          _fileIndex < oldWidget.attachments.length) {
        final currentUrl = oldWidget.attachments[_fileIndex].url;
        final preserved = widget.attachments.indexWhere(
          (item) => item.url == currentUrl,
        );
        if (preserved >= 0) {
          if (!widget.isPresenter) {
            final nextFile = widget.followFileIndex ?? _fileIndex;
            if (nextFile != _fileIndex &&
                nextFile >= 0 &&
                nextFile < widget.attachments.length) {
              _fileIndex = nextFile;
              _openLastPdfPage = false;
              _loadCurrent(initialPage: widget.followPage);
              return;
            }
          }
          if (preserved != _fileIndex) {
            _fileIndex = preserved;
            _openLastPdfPage = false;
            _loadCurrent(
              initialPage: widget.isPresenter ? null : widget.followPage,
            );
          }
          return;
        }
      }
      _fileIndex = widget.isPresenter ? 0 : (widget.followFileIndex ?? 0);
      _openLastPdfPage = false;
      _loadCurrent(initialPage: widget.isPresenter ? null : widget.followPage);
      return;
    }
    if (!widget.isPresenter) {
      final nextFile =
          widget.followFileIndex ?? widget.followViewport?.fileIndex ?? 0;
      final nextPage = widget.followPage ?? widget.followViewport?.page ?? 1;
      final viewportChanged = !_sameViewport(
        oldWidget.followViewport,
        widget.followViewport,
      );
      if (nextFile != _fileIndex) {
        _followTeacher = true;
        _fileIndex = nextFile;
        _loadCurrent(initialPage: nextPage);
        return;
      }
      if (nextPage != _pdfPage && _hasPdf) {
        _suppressPublish = true;
        // New slide from the teacher: snap back to following.
        _followTeacher = true;
        setState(() => _pdfPage = nextPage);
        _goToPage(nextPage).whenComplete(() {
          _suppressPublish = false;
          if (mounted) {
            _applyFollowViewport(force: true);
          }
        });
      }
      if (viewportChanged) {
        // Fresh teacher zoom always re-engages follow.
        _followTeacher = true;
        _applyFollowViewport(force: true);
      }
    }
  }

  bool _sameViewport(SlideViewport? a, SlideViewport? b) {
    if (identical(a, b)) {
      return true;
    }
    if (a == null || b == null) {
      return a == b;
    }
    return a.fileIndex == b.fileIndex &&
        a.page == b.page &&
        a.zoom == b.zoom &&
        a.cx == b.cx &&
        a.cy == b.cy &&
        a.ts == b.ts;
  }

  bool _sameAttachments(List<CourseAttachment> a, List<CourseAttachment> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i].url != b[i].url || a[i].name != b[i].name) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _publishDebounce?.cancel();
    _viewportThrottle?.cancel();
    _listenedController?.removeListener(_onMatrixChanged);
    _listenedController = null;
    _pdfController?.dispose();
    _windowsPdfController?.dispose();
    super.dispose();
  }

  void _publish() {
    if (!widget.isPresenter || _suppressPublish) {
      return;
    }
    final cb = widget.onSlideChanged;
    if (cb == null) {
      return;
    }
    _publishDebounce?.cancel();
    _publishDebounce = Timer(const Duration(milliseconds: 120), () {
      cb((fileIndex: _fileIndex, page: _pdfPage < 1 ? 1 : _pdfPage));
      if (_windowsPdfController != null) _sendViewport();
    });
  }

  Future<void> _loadCurrent({int? initialPage}) async {
    final file = _current;
    _listenedController?.removeListener(_onMatrixChanged);
    _listenedController = null;
    _pdfController?.dispose();
    _pdfController = null;
    _windowsPdfController?.dispose();
    _windowsPdfController = null;
    _officeViewer = null;
    _bytes = null;
    _pdfPage = initialPage ?? 1;
    if (_pdfPage < 1) {
      _pdfPage = 1;
    }
    _pdfPageCount = 0;
    _error = null;
    _isOffice = false;

    if (file == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final keyName = file.name.isNotEmpty ? file.name : file.url;
      final ext = courseFileExtension(keyName);

      if (isCoursePdf(keyName)) {
        final bytes = await loadCourseFileBytes(file.url);
        if (!mounted) {
          return;
        }
        final start = initialPage ?? 1;
        _openPdf(bytes, start);
      } else if (ext == 'pptx') {
        // Convert PPTX to PDF so page sync works in live lectures.
        try {
          final raw = await loadCourseFileBytes(file.url);
          if (!mounted) {
            return;
          }
          final pdfBytes = await presentationToPdfBytes(raw, fileName: keyName);
          if (!mounted) {
            return;
          }
          final start = initialPage ?? 1;
          _openPdf(pdfBytes, start);
        } catch (convertError) {
          debugPrint(
            'PPTX convert failed, trying Office WebView: $convertError',
          );
          await _loadOfficeWebView(file);
        }
      } else if (ext == 'ppt' ||
          const {'doc', 'docx', 'xls', 'xlsx'}.contains(ext)) {
        await _loadOfficeWebView(file);
      } else if (isCourseImage(keyName)) {
        _bytes = await loadCourseFileBytes(file.url);
      } else {
        _bytes = null;
      }
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      _publish();
      // Student: apply teacher zoom once the page geometry is ready.
      if (!widget.isPresenter && widget.followViewport != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _applyFollowViewport(force: true);
          }
        });
      }
    } catch (error, stack) {
      debugPrint('TopicSlidesViewer load failed: $error');
      debugPrint('$stack');
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context).slidesLoadFailed;
      });
    }
  }

  Future<void> _loadOfficeWebView(CourseAttachment file) async {
    if (_isWindows) {
      // These formats open in the installed desktop application. PDF/PPTX
      // continue to render inside LEARNsync and retain live page sync.
      return;
    }
    final publicUrl = await resolvePublicCourseFileUrl(
      courseId: widget.courseId,
      file: file,
    );
    if (!mounted) {
      return;
    }
    if (publicUrl == null || publicUrl.isEmpty) {
      _bytes = null;
      _isOffice = false;
      _officeViewer = null;
      _error = AppLocalizations.of(context).slidesLoadFailed;
      return;
    }
    final embed = officeEmbedUrl(publicUrl);
    _officeViewer = createOfficeDocumentView(embed);
    _isOffice = true;
    _bytes = null;
  }

  bool get _canGoPrev {
    if (!widget.isPresenter) {
      return false;
    }
    if (_hasPdf) {
      return _pdfPage > 1 || _fileIndex > 0;
    }
    return _fileIndex > 0;
  }

  bool get _canGoNext {
    if (!widget.isPresenter) {
      return false;
    }
    if (_hasPdf && _pdfPageCount > 0) {
      return _pdfPage < _pdfPageCount ||
          _fileIndex < widget.attachments.length - 1;
    }
    return _fileIndex < widget.attachments.length - 1;
  }

  Future<void> _prev() async {
    if (!_canGoPrev || _loading) {
      return;
    }
    if (_hasPdf && _pdfPage > 1) {
      await _goToPage(_pdfPage - 1);
      return;
    }
    if (_fileIndex > 0) {
      _openLastPdfPage = true;
      setState(() => _fileIndex -= 1);
      await _loadCurrent();
    }
  }

  Future<void> _next() async {
    if (!_canGoNext || _loading) {
      return;
    }
    if (_hasPdf && _pdfPageCount > 0 && _pdfPage < _pdfPageCount) {
      await _goToPage(_pdfPage + 1);
      return;
    }
    if (_fileIndex < widget.attachments.length - 1) {
      _openLastPdfPage = false;
      setState(() => _fileIndex += 1);
      await _loadCurrent();
    }
  }

  Future<void> _jumpToSlide() async {
    final controller = _pdfController ?? _windowsPdfController;
    if (!widget.isPresenter ||
        _loading ||
        controller == null ||
        _pdfPageCount < 1) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final formKey = GlobalKey<FormState>();
    final pageCount = _pdfPageCount;
    var input = '$_pdfPage';
    void submit(BuildContext dialogContext) {
      if (formKey.currentState!.validate()) {
        Navigator.of(dialogContext).pop(int.parse(input.trim()));
      }
    }

    final page = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.jumpToSlide),
        content: Form(
          key: formKey,
          child: TextFormField(
            initialValue: input,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.slideNumber,
              helperText: l10n.slidePageOf(1, pageCount),
            ),
            onChanged: (value) => input = value,
            onFieldSubmitted: (_) => submit(dialogContext),
            validator: (value) {
              final target = int.tryParse(value?.trim() ?? '');
              return target == null || target < 1 || target > pageCount
                  ? l10n.slideNumberOutOfRange(pageCount)
                  : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => submit(dialogContext),
            child: Text(l10n.jumpToSlide),
          ),
        ],
      ),
    );
    if (!mounted ||
        page == null ||
        !widget.isPresenter ||
        _loading ||
        controller != (_pdfController ?? _windowsPdfController) ||
        page > _pdfPageCount) {
      return;
    }
    // Use the existing page-change callback to publish the target to students.
    await _goToPage(page, duration: Duration.zero);
  }

  void _onDocumentLoaded(PdfDocument document) {
    if (!mounted) {
      return;
    }
    setState(() {
      _pdfPageCount = document.pagesCount;
      if (_openLastPdfPage) {
        _pdfPage = document.pagesCount;
      }
    });
    if (_openLastPdfPage && document.pagesCount > 1) {
      _openLastPdfPage = false;
      _goToPage(document.pagesCount, duration: Duration.zero);
    } else {
      _openLastPdfPage = false;
    }
    _publish();
    if (widget.isPresenter) {
      // Seed students with the teacher's fit-to-width view once layout is ready.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _sendViewport();
        }
      });
    } else {
      // Page rects are laid out after the first frame.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _applyFollowViewport(force: true),
      );
    }
  }

  // ---- Live zoom/pan sync ----

  void _listenViewport() {
    _listenedController?.removeListener(_onMatrixChanged);
    _listenedController = _pdfController;
    _listenedController?.addListener(_onMatrixChanged);
  }

  void _onMatrixChanged() {
    if (!mounted) {
      return;
    }
    if (widget.isPresenter) {
      if (widget.onViewportChanged == null || _applyingRemote) {
        return;
      }
      // Trailing throttle: reset so the last pinch frame is always published.
      _viewportThrottle?.cancel();
      _viewportThrottle = Timer(const Duration(milliseconds: 80), () {
        _viewportThrottle = null;
        _sendViewport();
      });
      return;
    }
    // Student pinched/panned with their own fingers: stop following.
    if (!_applyingRemote && _activePointers > 0 && _followTeacher) {
      setState(() => _followTeacher = false);
    }
  }

  void _sendViewport() {
    if (!mounted || !widget.isPresenter) {
      return;
    }
    final vp = _currentViewport();
    if (vp == null) {
      return;
    }
    final previous = _lastSentViewport;
    if (previous != null &&
        previous.fileIndex == vp.fileIndex &&
        previous.page == vp.page &&
        previous.zoom == vp.zoom &&
        previous.cx == vp.cx &&
        previous.cy == vp.cy) {
      return;
    }
    _lastSentViewport = vp;
    widget.onViewportChanged?.call(vp);
  }

  static double _round3(double v) => (v * 1000).roundToDouble() / 1000;

  SlideViewport? _currentViewport() {
    if (_windowsPdfController != null && _pdfPageCount > 0) {
      return (
        fileIndex: _fileIndex,
        page: _pdfPage,
        zoom: 1.0,
        cx: 0.5,
        cy: 0.5,
        ts: DateTime.now().millisecondsSinceEpoch,
      );
    }
    final c = _pdfController;
    if (c == null || _pdfPageCount == 0) {
      return null;
    }
    try {
      final page = _pdfPage.clamp(1, _pdfPageCount);
      final view = c.viewRect;
      final pageRect = c.getPageRect(page);
      final s = c.zoomRatio;
      if (pageRect == null ||
          s <= 0 ||
          view.width <= 0 ||
          pageRect.width <= 0 ||
          pageRect.height <= 0) {
        return null;
      }
      // view = s * doc + t  =>  doc = (view - t) / s; viewRect.left == -t.x
      final centerX = (view.left + view.width / 2) / s;
      final centerY = (view.top + view.height / 2) / s;
      return (
        fileIndex: _fileIndex,
        page: page,
        zoom: _round3(s * pageRect.width / view.width),
        cx: _round3(
          ((centerX - pageRect.left) / pageRect.width).clamp(-1.0, 2.0),
        ),
        cy: _round3(
          ((centerY - pageRect.top) / pageRect.height).clamp(-1.0, 2.0),
        ),
        ts: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  void _applyFollowViewport({bool force = false}) {
    if (!mounted || widget.isPresenter) {
      return;
    }
    if (!_followTeacher && !force) {
      return;
    }
    final vp = widget.followViewport;
    final c = _pdfController;
    if (vp == null || c == null || _pdfPageCount == 0) {
      return;
    }
    if (!force && vp.ts > 0 && vp.ts <= _lastAppliedViewportTs) {
      return;
    }
    // Wrong file: wait until didUpdateWidget loads the teacher file.
    if (vp.fileIndex != _fileIndex) {
      return;
    }
    if (vp.page < 1 || vp.page > _pdfPageCount) {
      return;
    }
    // Move to the teacher page first, then apply zoom on the next frame.
    if (vp.page != _pdfPage) {
      _followTeacher = true;
      _suppressPublish = true;
      setState(() => _pdfPage = vp.page);
      c
          .animateToPage(
            pageNumber: vp.page,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
          )
          .whenComplete(() {
            _suppressPublish = false;
            if (mounted) {
              _applyFollowViewport(force: true);
            }
          });
      return;
    }
    try {
      final view = c.viewRect;
      final pageRect = c.getPageRect(vp.page);
      if (pageRect == null ||
          view.width <= 0 ||
          pageRect.width <= 0 ||
          pageRect.height <= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _applyFollowViewport(force: true);
          }
        });
        return;
      }
      final zoom = vp.zoom.clamp(0.2, 12.0);
      final s = zoom * view.width / pageRect.width;
      final tx = view.width / 2 - s * (pageRect.left + vp.cx * pageRect.width);
      final ty = view.height / 2 - s * (pageRect.top + vp.cy * pageRect.height);
      final m = Matrix4.identity()
        ..setEntry(0, 0, s)
        ..setEntry(1, 1, s)
        ..setEntry(2, 2, 1)
        ..setTranslationRaw(tx, ty, 0);
      _applyingRemote = true;
      _lastAppliedViewportTs = vp.ts > 0 ? vp.ts : _lastAppliedViewportTs;
      // Instant matrix set is more reliable than animated goTo during live sync.
      c.value = m;
      _applyingRemote = false;
    } catch (error, stack) {
      debugPrint('applyFollowViewport failed: $error');
      debugPrint('$stack');
      _applyingRemote = false;
    }
  }

  void _snapToTeacher() {
    setState(() => _followTeacher = true);
    _applyFollowViewport(force: true);
  }

  void _onFollowerPointerDown(PointerDownEvent e) => _activePointers++;

  void _onFollowerPointerEnd(PointerEvent e) {
    _activePointers = _activePointers > 0 ? _activePointers - 1 : 0;
  }

  void _onFollowerPointerSignal(PointerSignalEvent e) {
    // Mouse wheel / trackpad zoom on a board or desktop counts as local zoom.
    if (e is PointerScrollEvent && _followTeacher && !widget.isPresenter) {
      setState(() => _followTeacher = false);
    }
  }

  void _onSwipePointerDown(PointerDownEvent e) {
    if (!widget.isPresenter) {
      return;
    }
    // Second finger = pinch/zoom; cancel slide swipe.
    if (_swipePointer != null) {
      _swipePointer = null;
      _swipeStart = null;
      return;
    }
    _swipePointer = e.pointer;
    _swipeStart = e.localPosition;
  }

  void _onSwipePointerUp(PointerUpEvent e) {
    if (e.pointer != _swipePointer || _swipeStart == null) {
      return;
    }
    final dx = e.localPosition.dx - _swipeStart!.dx;
    final dy = e.localPosition.dy - _swipeStart!.dy;
    _swipePointer = null;
    _swipeStart = null;
    // Clear horizontal swipe only (left = next, right = previous).
    if (dx.abs() < 70 || dx.abs() < dy.abs()) {
      return;
    }
    if (dx < 0) {
      unawaited(_next());
    } else {
      unawaited(_prev());
    }
  }

  void _onSwipePointerCancel(PointerCancelEvent e) {
    if (e.pointer == _swipePointer) {
      _swipePointer = null;
      _swipeStart = null;
    }
  }

  /// Presenter: horizontal swipe on slide area → same _prev/_next as arrows.
  Widget _wrapPresenterSwipe(Widget child) {
    if (!widget.isPresenter) {
      return child;
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onSwipePointerDown,
      onPointerUp: _onSwipePointerUp,
      onPointerCancel: _onSwipePointerCancel,
      child: child,
    );
  }

  String _pageLabel(AppLocalizations l10n) {
    final file = _current;
    if (file == null) {
      return '';
    }
    if (_hasPdf && _pdfPageCount > 0) {
      if (widget.hideFileInLabel || widget.attachments.length == 1) {
        return l10n.slidePageOf(_pdfPage, _pdfPageCount);
      }
      return l10n.slideFilePageOf(
        _fileIndex + 1,
        widget.attachments.length,
        _pdfPage,
        _pdfPageCount,
      );
    }
    if (widget.hideFileInLabel || widget.attachments.length <= 1) {
      return file.name;
    }
    return l10n.slideFileOf(_fileIndex + 1, widget.attachments.length);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final file = _current;

    if (widget.attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    return CallbackShortcuts(
      bindings: {
        if (widget.isPresenter) ...{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _prev(),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _next(),
          const SingleActivator(LogicalKeyboardKey.keyJ, control: true): () =>
              _jumpToSlide(),
        },
      },
      child: Focus(
        autofocus: widget.isPresenter,
        child: Material(
          color: AppColors.fieldFill(brightness),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border(brightness)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.teal,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title ?? l10n.topicSlides,
                          style: TextStyle(
                            color: AppColors.textPrimary(brightness),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (widget.isPresenter)
                        IconButton(
                          tooltip: l10n.jumpToSlide,
                          onPressed: !_loading && _hasPdf && _pdfPageCount > 0
                              ? _jumpToSlide
                              : null,
                          icon: const Icon(Icons.low_priority_rounded),
                          color: AppColors.teal,
                        ),
                      if (!widget.isPresenter && !_followTeacher)
                        ActionChip(
                          avatar: const Icon(
                            Icons.my_location_rounded,
                            size: 16,
                            color: AppColors.teal,
                          ),
                          label: Text(
                            l10n.liveFollowTeacher,
                            style: const TextStyle(
                              color: AppColors.teal,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: _snapToTeacher,
                        )
                      else if (!widget.isPresenter)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l10n.followingTeacher,
                            style: const TextStyle(
                              color: AppColors.teal,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) => SizedBox(
                    height: constraints.maxWidth >= 700
                        ? (constraints.maxWidth * 9 / 16).clamp(360.0, 760.0)
                        : _isOffice
                        ? 420
                        : 360,
                    child: _wrapPresenterSwipe(
                      _buildBody(l10n, brightness, file),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l10n.previousPage,
                        onPressed: _canGoPrev && !_loading ? _prev : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                        color: AppColors.teal,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              _pageLabel(l10n),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary(brightness),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            if (file != null && file.name.trim().isNotEmpty)
                              Text(
                                file.name,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary(brightness),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.nextPage,
                        onPressed: _canGoNext && !_loading ? _next : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                        color: AppColors.teal,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    AppLocalizations l10n,
    Brightness brightness,
    CourseAttachment? file,
  ) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary(brightness)),
              ),
              if (file != null) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => openCourseFile(file.url),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(l10n.openFile),
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (file == null) {
      return const SizedBox.shrink();
    }

    final keyName = file.name.isNotEmpty ? file.name : file.url;
    Widget child;
    if (_windowsPdfController != null) {
      child = PdfView(
        controller: _windowsPdfController!,
        onDocumentLoaded: _onDocumentLoaded,
        onPageChanged: (page) {
          if (!mounted) return;
          setState(() => _pdfPage = page);
          _publish();
        },
        // Students receive page changes from the live session.
        physics: widget.isPresenter
            ? null
            : const NeverScrollableScrollPhysics(),
      );
    } else if (_pdfController != null) {
      child = PdfViewPinch(
        controller: _pdfController!,
        onDocumentLoaded: _onDocumentLoaded,
        onPageChanged: (page) {
          if (!mounted) {
            return;
          }
          setState(() => _pdfPage = page);
          _publish();
        },
      );
      if (!widget.isPresenter) {
        child = Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onFollowerPointerDown,
          onPointerUp: _onFollowerPointerEnd,
          onPointerCancel: _onFollowerPointerEnd,
          onPointerSignal: _onFollowerPointerSignal,
          child: child,
        );
      }
    } else if (_officeViewer != null) {
      child = _officeViewer!;
      if (!widget.isPresenter) {
        // Students follow teacher; block independent PPT navigation.
        child = AbsorbPointer(child: child);
      }
    } else if (isCourseImage(keyName) && _bytes != null) {
      child = InteractiveViewer(
        minScale: 0.8,
        maxScale: 4,
        child: Center(child: Image.memory(_bytes!, fit: BoxFit.contain)),
      );
    } else {
      child = Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.insert_drive_file_outlined,
                size: 48,
                color: AppColors.teal,
              ),
              const SizedBox(height: 12),
              Text(
                file.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary(brightness),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.slidesOpenExternally,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary(brightness),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => openCourseFile(file.url),
                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(l10n.openFile),
              ),
            ],
          ),
        ),
      );
    }
    return child;
  }
}
