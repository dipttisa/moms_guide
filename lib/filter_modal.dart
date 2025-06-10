import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FilterModal extends StatefulWidget {
  final Function(List<String>) onFiltersApplied;

  const FilterModal({Key? key, required this.onFiltersApplied}) : super(key: key);

  @override
  _FilterModalState createState() => _FilterModalState();
}

class _FilterModalState extends State<FilterModal> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _trimesters = [];
  Map<String, List<Map<String, dynamic>>> _symptomsByTrimester = {};
  Set<String> _selectedSymptomIds = {};
  Set<String> _expandedTrimesters = {};
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadTrimestersAndSymptoms();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadTrimestersAndSymptoms() async {
    if (_isDisposed) return;

    try {
      final trimestersResponse = await supabase
          .from('trimester')
          .select('id, number')
          .order('number');

      if (!mounted || _isDisposed) return;

      setState(() {
        _trimesters = List<Map<String, dynamic>>.from(trimestersResponse);
      });

      for (var trimester in _trimesters) {
        if (!mounted || _isDisposed) return;

        final symptomsResponse = await supabase
            .from('trimester_symptoms')
            .select('symptom_id, symptom!inner(id, name)')
            .eq('trimester_id', trimester['id']);

        if (!mounted || _isDisposed) return;

        setState(() {
          _symptomsByTrimester[trimester['id']] = 
              List<Map<String, dynamic>>.from(symptomsResponse)
                  .map((item) => item['symptom'] as Map<String, dynamic>)
                  .toList();
        });
      }
    } catch (e) {
      if (!mounted || _isDisposed) return;
      print('Error loading trimesters and symptoms: $e');
    }
  }

  void _toggleSymptom(String symptomId) {
    if (!mounted || _isDisposed) return;
    
    setState(() {
      if (_selectedSymptomIds.contains(symptomId)) {
        _selectedSymptomIds.remove(symptomId);
      } else {
        _selectedSymptomIds.add(symptomId);
      }
    });
  }

  void _toggleTrimester(String trimesterId) {
    if (!mounted || _isDisposed) return;
    
    setState(() {
      if (_expandedTrimesters.contains(trimesterId)) {
        _expandedTrimesters.remove(trimesterId);
      } else {
        _expandedTrimesters.add(trimesterId);
      }
    });
  }

  void _applyFilters() {
    if (!mounted || _isDisposed) return;
    widget.onFiltersApplied(_selectedSymptomIds.toList());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Color(0xFFBE7DBC).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Фильтр по симптомам',
                  style: TextStyle(
                    fontFamily: 'Comfortaa',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color.fromARGB(255, 54, 6, 56),
                  ),
                ),
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.only(left: 15),
                  child: Text(
                    'Выберите симптомы для фильтрации статей',
                    style: TextStyle(
                      fontFamily: 'Comfortaa',
                      fontSize: 14,
                      color: Color.fromARGB(255, 54, 6, 56).withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _trimesters.length,
              itemBuilder: (context, trimesterIndex) {
                final trimester = _trimesters[trimesterIndex];
                final symptoms = _symptomsByTrimester[trimester['id']] ?? [];
                final isExpanded = _expandedTrimesters.contains(trimester['id']);
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 24, bottom: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFFF2E4E1).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _toggleTrimester(trimester['id']),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${trimester['number']} триместр',
                                  style: TextStyle(
                                    fontFamily: 'Comfortaa',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color.fromARGB(255, 54, 6, 56),
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: isExpanded ? 0.5 : 0,
                                  duration: Duration(milliseconds: 200),
                                  child: Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Color.fromARGB(255, 54, 6, 56),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isExpanded) ...[
                      ...symptoms.map((symptom) => Container(
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: _selectedSymptomIds.contains(symptom['id'])
                              ? Color(0xFFBE7DBC).withOpacity(0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedSymptomIds.contains(symptom['id'])
                                ? Color(0xFFBE7DBC)
                                : Color(0xFFBE7DBC).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _toggleSymptom(symptom['id']),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _selectedSymptomIds.contains(symptom['id'])
                                            ? Color(0xFFBE7DBC)
                                            : Color(0xFFBE7DBC).withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: _selectedSymptomIds.contains(symptom['id'])
                                        ? Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Color(0xFFBE7DBC),
                                          )
                                        : null,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      symptom['name'],
                                      style: TextStyle(
                                        fontFamily: 'Comfortaa',
                                        fontSize: 14,
                                        color: Color.fromARGB(255, 54, 6, 56),
                                        fontWeight: _selectedSymptomIds.contains(symptom['id'])
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )).toList(),
                    ],
                  ],
                );
              },
            ),
          ),
          
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      if (!mounted || _isDisposed) return;
                      setState(() {
                        _selectedSymptomIds.clear();
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Color(0xFFBE7DBC)),
                      ),
                    ),
                    child: Text(
                      'Сбросить',
                      style: TextStyle(
                        fontFamily: 'Comfortaa',
                        fontSize: 16,
                        color: Color(0xFFBE7DBC),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFBE7DBC),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Применить',
                      style: TextStyle(
                        fontFamily: 'Comfortaa',
                        fontSize: 16,
                        color: Colors.white,
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