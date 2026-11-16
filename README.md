# LEARNsync 📚

### Smart Mobile Teaching & Learning Platform

LEARNsync is a cross-platform educational mobile application designed to improve communication between teachers and students through real-time learning feedback.

The platform allows teachers to start a live topic during a lecture, while students can privately report their level of understanding, practice the topic using AI-generated questions, or request additional support from their teacher.

---

## 🎯 Project Objective

In a traditional classroom, teachers may not always know whether every student has understood the current topic.

LEARNsync addresses this problem by providing a simple and private way for students to communicate their understanding while giving teachers structured learning insights.

### Core Learning Flow

Teacher starts a topic  
↓  
Topic becomes available to students  
↓  
Students report their understanding  
↓  
Students choose AI Practice or Teacher Support  
↓  
AI generates topic-specific practice  
↓  
Teacher reviews learning analytics

---

## 👥 User Roles

LEARNsync currently focuses on two main user interfaces:

### 👨‍🏫 Teacher

Teachers can:

- Login to the application
- View chapters and topics
- Start the topic being taught
- Monitor student understanding
- Review AI practice engagement
- View learning analytics
- Review student meeting requests

### 👨‍🎓 Student

Students can:

- Login to the application
- Receive the currently active topic
- Privately report their understanding
- Choose AI Practice
- Answer AI-generated questions
- View practice results
- Request a meeting with the teacher

---

# 🚀 Main Modules

## 1. Authentication & User Management

- Teacher and Student authentication
- Role-based application access
- User profiles
- Session management

---

## 2. Teacher Module

The teacher module provides the tools required to manage classroom topics and monitor student feedback.

### Features

- Chapter selection
- Topic selection
- Start live topic
- End topic
- Monitor student responses
- Review support requests
- View analytics

---

## 3. Student Module

The student module provides a private way for students to communicate their understanding.

### Understanding Levels

Students can select:

- 100%
- 80%
- 60%
- Below 50%

After submitting their understanding level, students can choose between:

- AI Practice
- Request Teacher Meeting

---

# 🤖 AI Practice Module

AI Practice is one of the core features of LEARNsync.

The system generates topic-specific practice questions so students can immediately test their understanding.

### AI Features

- Topic-based question generation
- MCQ generation
- True/False questions
- Fill-in-the-blank questions
- Numerical/conceptual questions
- Answer evaluation
- Score calculation
- Learning feedback

### Local AI

LEARNsync is designed to use a **local/on-device AI model** instead of depending on a cloud AI API.

The application targets:

- Android
- iOS

A small quantized language model will be evaluated and integrated for on-device inference.

### AI Flow

```text
Current Topic
     ↓
Student starts AI Practice
     ↓
Local AI Model
     ↓
Generate Questions
     ↓
Student Answers
     ↓
Answer Evaluation
     ↓
Score & Feedback
