import 'package:flutter/material.dart';

class SymptomWarningModal extends StatelessWidget {
  final String symptomName;
  final String warningMessage;
  final int severityLevel;

  const SymptomWarningModal({
    Key? key,
    required this.symptomName,
    required this.warningMessage,
    required this.severityLevel,
  }) : super(key: key);

  static Future<void> show({
    required BuildContext context,
    required String symptomName,
    required String warningMessage,
    required int severityLevel,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SymptomWarningModal(
        symptomName: symptomName,
        warningMessage: warningMessage,
        severityLevel: severityLevel,
      ),
    );
  }

  Color _getSeverityColor() {
    switch (severityLevel) {
      case 1:
        return const Color(0xFFFFA726); // Orange for low severity
      case 2:
        return const Color(0xFFFF7043); // Deep Orange for medium severity
      case 3:
        return const Color(0xFFE53935); // Red for high severity
      default:
        return const Color(0xFFFFA726);
    }
  }

  IconData _getSeverityIcon() {
    switch (severityLevel) {
      case 1:
        return Icons.info_outline;
      case 2:
        return Icons.warning_amber_outlined;
      case 3:
        return Icons.error_outline;
      default:
        return Icons.info_outline;
    }
  }

  String _getSeverityText() {
    switch (severityLevel) {
      case 1:
        return 'Низкая';
      case 2:
        return 'Средняя';
      case 3:
        return 'Высокая';
      default:
        return 'Низкая';
    }
  }

  @override
  Widget build(BuildContext context) {
    final severityColor = _getSeverityColor();
    
    return Container(
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 50,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFBE7DBC).withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon and severity
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: severityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getSeverityIcon(),
                        color: severityColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            symptomName,
                            style: const TextStyle(
                              fontFamily: 'Comfortaa',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color.fromARGB(255, 54, 6, 56),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Уровень опасности: ${_getSeverityText()}',
                            style: TextStyle(
                              fontFamily: 'Comfortaa',
                              fontSize: 14,
                              color: severityColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Warning message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2E4E1).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: severityColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    warningMessage,
                    style: const TextStyle(
                      fontFamily: 'Comfortaa',
                      fontSize: 16,
                      color: Color.fromARGB(255, 54, 6, 56),
                      height: 1.5,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBE7DBC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Понятно',
                      style: TextStyle(
                        fontFamily: 'Comfortaa',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 