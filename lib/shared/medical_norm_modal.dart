import 'package:flutter/material.dart';

class MedicalNormModal extends StatelessWidget {
  final int trimester;
  final double? hemoglobin;
  final double? glucoseFasting;// Глюкоза натощак (ммоль/л)
  final double? glucose1hAfterMeal;// Тест толерантности к глюкозе (да/нет)

  const MedicalNormModal({
    Key? key,
    required this.trimester,
    this.hemoglobin,
    this.glucoseFasting,
    this.glucose1hAfterMeal,
  }) : super(key: key);

  static Future<void> show({
    required BuildContext context,
    required int trimester,
    double? hemoglobin,
    double? glucoseFasting,
    double? glucose1hAfterMeal,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MedicalNormModal(
        trimester: trimester,
        hemoglobin: hemoglobin,
        glucoseFasting: glucoseFasting,
        glucose1hAfterMeal: glucose1hAfterMeal,
       
      ),
    );
  }
  String _getHemoglobinNormText() {
    switch (trimester) {
      case 1:
        return 'Норма гемоглобина: 115–140 г/л';
      case 2:
        return 'Норма гемоглобина: 110–135 г/л';
      case 3:
        return 'Норма гемоглобина: 105–130 г/л';
      default:
        return 'Норма гемоглобина зависит от триместра.';
    }
  }

  Color _getHemoglobinColor() {
    if (hemoglobin == null) return Colors.grey;

    final ranges = {
      1: [115.0, 140.0],
      2: [110.0, 135.0],
      3: [105.0, 130.0],
    };

    final range = ranges[trimester];
    if (range == null) return Colors.grey;

    if (hemoglobin! < range[0] || hemoglobin! > range[1]) {
      return Colors.red; // ниже или выше нормы — красный
    }
    return Colors.green; // в норме — зелёный
  }

  // Текст нормы для глюкозы с учётом теста толерантности
  String _getGlucoseNormText() {
    
      return 'Норма сахара крови:\n' +
             '- Утром натощак — не более 5,0 ммоль/л\n' +
             '- Через 1 час после еды — не более 7,0 ммоль/л';
    
  }

  // Проверка цвета глюкозы по значениям
  Color _getGlucoseColor() {
    
      
      // обычный случай без теста толерантности
      if (glucoseFasting != null && glucoseFasting! > 5.0) return Colors.red;
      if (glucose1hAfterMeal != null && glucose1hAfterMeal! > 7.0) return Colors.red;
      // если есть значения и они в норме — зелёный
      if ((glucoseFasting != null && glucoseFasting! <= 5.0) ||
          (glucose1hAfterMeal != null && glucose1hAfterMeal! <= 7.0)) {
        return Colors.green;
      }
      return Colors.grey;
    
  }

  @override
  Widget build(BuildContext context) {
    final hemoglobinColor = _getHemoglobinColor();
    final glucoseColor = _getGlucoseColor();

    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 50),
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
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок
                  Text(
                    'Медицинские показатели',
                    style: const TextStyle(
                      fontFamily: 'Comfortaa',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color.fromARGB(255, 54, 6, 56),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(Icons.bloodtype_outlined, color: hemoglobinColor, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Гемоглобин',
                              style: TextStyle(
                                fontFamily: 'Comfortaa',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: hemoglobinColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getHemoglobinNormText(),
                              style: const TextStyle(
                                fontFamily: 'Comfortaa',
                                fontSize: 14,
                                color: Color.fromARGB(255, 54, 6, 56),
                              ),
                            ),
                            if (hemoglobin != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Ваш результат: ${hemoglobin!.toStringAsFixed(1)} г/л',
                                  style: TextStyle(
                                    fontFamily: 'Comfortaa',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: hemoglobinColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(Icons.monitor_heart_outlined, color: glucoseColor, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Глюкоза',
                              style: TextStyle(
                                fontFamily: 'Comfortaa',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: glucoseColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getGlucoseNormText(),
                              style: const TextStyle(
                                fontFamily: 'Comfortaa',
                                fontSize: 14,
                                color: Color.fromARGB(255, 54, 6, 56),
                              ),
                            ),
                            if (glucoseFasting != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Натощак: ${glucoseFasting!.toStringAsFixed(1)} ммоль/л',
                                  style: TextStyle(
                                    fontFamily: 'Comfortaa',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: glucoseColor,
                                  ),
                                ),
                              ),
                            if (glucose1hAfterMeal != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Через 1 час после еды: ${glucose1hAfterMeal!.toStringAsFixed(1)} ммоль/л',
                                  style: TextStyle(
                                    fontFamily: 'Comfortaa',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: glucoseColor,
                                  ),
                                ),
                              ),
                  const SizedBox(height: 24),
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
      ],
    ))
  ])));
  }
}
