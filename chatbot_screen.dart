import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/chatbot_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ChatbotService _chatbotService = ChatbotService();
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isProcessing = false;
  String _activeMessageId = '';

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    _loadChatHistory();
    
    // Add welcome message
    _addBotMessage(
      "Hi there! I'm your Guardian AI assistant. How can I help you today?",
      'neutral'
    );
  }
  
  Future<void> _initializeTTS() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    });
  }

  Future<void> _loadChatHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chat_history')
          .doc(user.uid)
          .collection('messages')
          .orderBy('timestamp')
          .limit(20) // Limit to recent messages
          .get();

      final loadedMessages = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'text': data['text'] ?? '',
          'isUser': data['sender'] == 'user',
          'sentiment': data['sentiment'] ?? 'neutral',
          'timestamp': data['timestampStr'] ?? '',
          'id': doc.id,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _messages.clear(); // Clear any existing messages
          _messages.addAll(loadedMessages);
        });
      }
    } catch (e) {
      print("Error loading chat history: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _flutterTts.stop();
    _speech.stop();
    super.dispose();
  }

  void _addBotMessage(String text, String sentiment) {
    final timestamp = DateFormat('hh:mm a').format(DateTime.now());
    
    if (mounted) {
      setState(() {
        _messages.add({
          'text': text,
          'isUser': false,
          'sentiment': sentiment,
          'timestamp': timestamp,
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
        });
      });
    }
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _chatbotService.saveChat(user.uid, 'bot', text, timestamp);
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isProcessing) return;

    setState(() => _isProcessing = true);
    
    final timestamp = DateFormat('hh:mm a').format(DateTime.now());
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();

    setState(() {
      _messages.add({
        'text': text,
        'isUser': true,
        'sentiment': 'neutral', // Default sentiment for user messages
        'timestamp': timestamp,
        'id': messageId,
      });
    });

    _controller.clear();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _chatbotService.saveChat(user.uid, 'user', text, timestamp);
    }

    // Analyze sentiment first
    final sentiment = await _chatbotService.analyzeSentiment(text);
    print("Message sentiment: $sentiment");

    // Check for distress and trigger SOS if needed
    if (sentiment == 'distress' && user != null) {
      _addBotMessage(
        "I detect you may be in distress. Sending an SOS alert to your emergency contacts.",
        'distress'
      );
      
      await _chatbotService.sendSOS(user.uid);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 SOS alert has been sent to your emergency contacts!'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 5),
        ),
      );
    }

    // Get chatbot response
    try {
      final botResponse = await _chatbotService.getChatbotReply(text);
      final botTimestamp = DateFormat('hh:mm a').format(DateTime.now());

      setState(() {
        _messages.add({
          'text': botResponse,
          'isUser': false,
          'sentiment': sentiment,
          'timestamp': botTimestamp,
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
        });
      });

      if (user != null) {
        await _chatbotService.saveChat(user.uid, 'bot', botResponse, botTimestamp);
      }

      _speak(botResponse);
    } catch (e) {
      print("Error getting bot response: $e");
      _addBotMessage(
        "I'm having trouble responding right now. Please try again in a moment.",
        'neutral'
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _speak(String text) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
    }
    
    setState(() => _isSpeaking = true);
    await _flutterTts.speak(text);
  }

  Future<void> _listen() async {
    if (!_isListening) {
      final available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _controller.text = result.recognizedWords;
            });
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          onSoundLevelChange: (level) {},
          cancelOnError: true,
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      
      // Send the message if speech contains text
      if (_controller.text.isNotEmpty) {
        _sendMessage(_controller.text);
      }
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['isUser'] as bool;
    final sentiment = message['sentiment'] as String? ?? 'neutral';
    final messageId = message['id'] as String? ?? '';
    
    // Set bubble colors based on sender and sentiment
    Color bubbleColor;
    switch (sentiment) {
      case 'positive':
        bubbleColor = isUser ? Colors.green.shade100 : Colors.lightBlue.shade100;
        break;
      case 'distress':
        bubbleColor = isUser ? Colors.red.shade100 : Colors.red.shade100;
        break;
      default:
        bubbleColor = isUser ? Colors.blueAccent : Colors.grey.shade300;
    }

    // Set emoji based on sentiment
    final emoji = {
      'positive': '😊',
      'distress': '🚨',
      'neutral': isUser ? '' : '🤖',
    }[sentiment];

    // Check if this message is currently being spoken
    final bool isMessageSpeaking = _isSpeaking && _activeMessageId == messageId;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: isUser ? null : () {
          setState(() => _activeMessageId = messageId);
          _speak(message['text']);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isUser)
                    Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: Icon(
                        isMessageSpeaking ? Icons.volume_up : Icons.volume_mute,
                        color: isMessageSpeaking ? Colors.blue : Colors.grey,
                        size: 16,
                      ),
                    ),
                  Flexible(
                    child: Text(
                      message['text'],
                      style: const TextStyle(fontSize: 16, color: Colors.black),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment:
                    isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (!isUser && emoji != null && emoji.isNotEmpty)
                    Text(
                      emoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                  const SizedBox(width: 4),
                  Text(
                    message['timestamp'] ?? '',
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian AI Chatbot'),
        backgroundColor: Colors.blue.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChatHistory,
            tooltip: 'Reload chat history',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
            ? const Center(
                child: Text('No messages yet. Start a conversation!'),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: _messages.length,
                itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
              ),
          ),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  onPressed: _listen,
                  color: _isListening ? Colors.red : null,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                    ),
                    onSubmitted: (text) => _sendMessage(text),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(_controller.text),
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}