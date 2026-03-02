// lib/screens/quiz/quiz_screen.dart

import 'package:flutter/material.dart';
import 'package:prep_ng/provider/quiz_provider.dart'; 
import 'package:provider/provider.dart';
import 'result_screen.dart';

class QuizScreen extends StatefulWidget {
  final String subjectName;
  
  const QuizScreen({
    super.key,
    required this.subjectName,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  
  // Navigation function that the provider will call when the quiz ends
  void _navigateToResults(QuizProvider provider) {
    // Navigate and replace the current screen, passing the necessary results data
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          subjectName: widget.subjectName,
          questions: provider.questions,
          userAnswers: provider.userAnswers, // Uses the new getter
          score: provider.score,
        ),
      ),
    );
  }

  // 2. CALLBACK REGISTRATION
  @override
  void initState() {
    super.initState();
    // Get the provider instance without listening (listen: false)
    final quizProvider = Provider.of<QuizProvider>(context, listen: false);
    
    // Register the callback function for when the quiz ends (timer or submit)
    quizProvider.onQuizFinished = () => _navigateToResults(quizProvider);
  }

  // 3. CALLBACK DEREGISTRATION
  @override
  void dispose() {
    // IMPORTANT: Clear the callback reference when the widget is closed 
    // to prevent calling setState() on a disposed widget later.
    Provider.of<QuizProvider>(context, listen: false).onQuizFinished = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We use Consumer here as before to rebuild the UI on state changes
    return Consumer<QuizProvider>(
      builder: (context, quizProvider, child) {
        
        // Safety check: If for some reason the quiz is finished, the provider's callback 
        // should have already handled the navigation, but this is a fallback.
        if (quizProvider.isQuizFinished) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Instead of pop(), we ensure the callback is called if not already done
            if (quizProvider.onQuizFinished != null) {
              quizProvider.onQuizFinished!(); 
            }
          });
          return const Scaffold(body: Center(child: Text('Navigating to results...')));
        }
        
        final question = quizProvider.currentQuestion;
        
        // Calculate minutes and seconds remaining
        final int minutes = quizProvider.timeRemaining ~/ 60;
        final int seconds = quizProvider.timeRemaining % 60;
        final String timerText = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

        return PopScope(
          canPop: false, 
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.subjectName),
              automaticallyImplyLeading: false, 
              backgroundColor: Colors.green.shade700,
              actions: [
                // Timer Display
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: Text(
                      timerText,
                      style: const TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress and Question Number
                  Text(
                    'Question ${quizProvider.currentQuestionIndex + 1} of ${quizProvider.questions.length}',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 10),
                  
                  // Question Text
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        question.text,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Question Image (if available)
                  if (question.imagePath != null && question.imagePath!.isNotEmpty)
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            question.imagePath!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                color: Colors.grey.shade200,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, color: Colors.grey.shade600),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Image not found',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  if (question.imagePath != null && question.imagePath!.isNotEmpty)
                    const SizedBox(height: 20),
                  
                  // Options List
                  Expanded(
                    child: ListView.builder(
                      itemCount: question.options.length,
                      itemBuilder: (context, index) {
                        final optionText = question.options[index];
                        final isSelected = index == quizProvider.selectedAnswerIndex;
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: OptionTile(
                            text: optionText,
                            index: index,
                            isSelected: isSelected,
                            onTap: () => quizProvider.selectAnswer(index),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Navigation Bar
            bottomNavigationBar: QuizNavigationBar(quizProvider: quizProvider),
          ),
        );
      },
    );
  }
}

// --- Helper Widgets (OptionTile and QuizNavigationBar remain outside the State class) ---

// 2. OptionTile Widget (No changes needed)
class OptionTile extends StatelessWidget {
  // ... (content of OptionTile)
  final String text;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const OptionTile({
    required this.text,
    required this.index,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? Colors.green.shade700 : Colors.grey.shade400,
                shape: BoxShape.circle,
              ),
              child: Text(
                String.fromCharCode('A'.codeUnitAt(0) + index), // Display A, B, C, D
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

// 3. QuizNavigationBar Widget (Updated Submit logic)
class QuizNavigationBar extends StatelessWidget {
  final QuizProvider quizProvider;

  const QuizNavigationBar({required this.quizProvider, super.key});

  @override
  Widget build(BuildContext context) {
    final isLastQuestion = quizProvider.currentQuestionIndex == quizProvider.questions.length - 1;
    final isFirstQuestion = quizProvider.currentQuestionIndex == 0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Button
          ElevatedButton.icon(
            onPressed: isFirstQuestion ? null : quizProvider.previousQuestion,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Previous'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade300,
              foregroundColor: Colors.black,
            ),
          ),
          
          // Next / Submit Button
          ElevatedButton.icon(
            onPressed: () {
              if (isLastQuestion) {
                // 4. UPDATED SUBMIT LOGIC: Call the registered callback (onQuizFinished)
                if (quizProvider.onQuizFinished != null) {
                  quizProvider.onQuizFinished!();
                }
              } else {
                quizProvider.nextQuestion();
              }
            },
            icon: Icon(isLastQuestion ? Icons.check : Icons.arrow_forward),
            label: Text(isLastQuestion ? 'Submit Quiz' : 'Next Question'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isLastQuestion ? Colors.red.shade700 : Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}