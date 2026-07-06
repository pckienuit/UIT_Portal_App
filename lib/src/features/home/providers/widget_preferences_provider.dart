import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

const _kWidgetPreferencesKey = 'widget_preferences';

class WidgetPreferencesNotifier extends Notifier<List<String>> {
  static const defaultWidgets = ['schedule', 'tuition', 'grades'];

  @override
  List<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs.getStringList(_kWidgetPreferencesKey);
    return saved ?? defaultWidgets;
  }

  void toggleWidget(String widgetId, bool isEnabled) {
    final currentState = state;
    final List<String> newState = List.from(currentState);
    
    if (isEnabled && !newState.contains(widgetId)) {
      newState.add(widgetId);
    } else if (!isEnabled && newState.contains(widgetId)) {
      newState.remove(widgetId);
    }

    state = newState;
    _saveToPrefs(newState);
  }

  void reorderWidgets(int oldIndex, int newIndex) {
    final currentState = state;
    final List<String> newState = List.from(currentState);
    
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = newState.removeAt(oldIndex);
    newState.insert(newIndex, item);

    state = newState;
    _saveToPrefs(newState);
  }

  void _saveToPrefs(List<String> prefsList) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setStringList(_kWidgetPreferencesKey, prefsList);
  }
}

final widgetPreferencesProvider = NotifierProvider<WidgetPreferencesNotifier, List<String>>(() {
  return WidgetPreferencesNotifier();
});
