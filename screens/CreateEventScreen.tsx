import React, { useState } from 'react';
import {
View,
Text,
TextInput,
TouchableOpacity,
StyleSheet,
ActivityIndicator,
Alert,
ScrollView,
Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { showSuccess } from '../utils/notifications';
import { triggerSuccessHaptic } from '../utils/haptics';
import { useMutation } from 'convex/react';
import { api } from '../convex/_generated/api';
import { theme } from '../lib/theme';
import { Ionicons } from '@expo/vector-icons';

interface Props {
  profile: {
    villageId: any;
  };
  navigation: any;
}

export default function CreateEventScreen({ profile, navigation }: Props) {
  const createEvent = useMutation(api.events.createEvent);

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [date, setDate] = useState('');
  const [time, setTime] = useState('');
  const [saving, setSaving] = useState(false);

  const handleSave = async () => {
    if (!title.trim() || !date.trim() || !time.trim()) {
      Alert.alert('Missing info', 'Please enter a title, date, and time.');
      return;
    }

    setSaving(true);
    try {
      await createEvent({
        villageId: profile.villageId,
        title: title.trim(),
        description: description.trim(),
        date: date.trim(),
        time: time.trim(),
      });

      triggerSuccessHaptic();
      showSuccess('Event created!');
      navigation.goBack();
    } catch (error: any) {
      console.error(error);
      Alert.alert('Error', error?.message ?? 'Failed to create event');
      setSaving(false);
    }
  };

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <View style={styles.header}>
        <TouchableOpacity
          style={styles.closeBtn}
          onPress={() => navigation.goBack()}
          accessibilityLabel="Close screen"
          accessibilityHint="Return to the previous screen"
          accessibilityRole="button"
        >
          <Ionicons name={Platform.OS === 'ios' ? 'close' : 'arrow-back'} size={22} color={theme.colors.text.primary} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>New Event</Text>
        <View style={{ width: 40 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <Text style={styles.label}>Title</Text>
        <TextInput
          style={styles.input}
          placeholder="e.g., Playdate at the park"
          placeholderTextColor={theme.colors.gray.medium}
          value={title}
          onChangeText={setTitle}
          accessibilityLabel="Event title"
          accessibilityHint="Enter a title for the event"
        />

        <Text style={styles.label}>Description (optional)</Text>
        <TextInput
          style={[styles.input, styles.textArea]}
          placeholder="Details, what to bring, etc."
          placeholderTextColor={theme.colors.gray.medium}
          value={description}
          onChangeText={setDescription}
          multiline
          accessibilityLabel="Event description"
          accessibilityHint="Enter optional details about the event"
        />

        <Text style={styles.label}>Date</Text>
        <TextInput
          style={styles.input}
          placeholder="YYYY-MM-DD"
          placeholderTextColor={theme.colors.gray.medium}
          value={date}
          onChangeText={setDate}
          autoCapitalize="none"
          accessibilityLabel="Event date"
          accessibilityHint="Enter the event date in YYYY-MM-DD format"
        />

        <Text style={styles.label}>Time</Text>
        <TextInput
          style={styles.input}
          placeholder="e.g., 3:30 PM"
          placeholderTextColor={theme.colors.gray.medium}
          value={time}
          onChangeText={setTime}
          accessibilityLabel="Event time"
          accessibilityHint="Enter the event time"
        />

        <TouchableOpacity
          style={[styles.button, (saving || !title.trim()) && styles.buttonDisabled]}
          onPress={handleSave}
          disabled={saving}
          accessibilityLabel="Create event"
          accessibilityHint="Create the new village event"
          accessibilityRole="button"
        >
          {saving ? <ActivityIndicator color={theme.colors.white} /> : <Text style={styles.buttonText}>Create Event</Text>}
        </TouchableOpacity>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: theme.colors.background,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 14,
    backgroundColor: theme.colors.white,
    borderBottomWidth: 1,
    borderBottomColor: theme.colors.gray.light,
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: theme.colors.text.primary,
  },
  closeBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: theme.colors.background,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
  },
  content: {
    padding: 16,
    paddingBottom: 40,
  },
  label: {
    fontSize: 13,
    fontWeight: '700',
    color: theme.colors.text.secondary,
    marginBottom: 8,
    marginTop: 12,
  },
  input: {
    backgroundColor: theme.colors.white,
    borderRadius: 12,
    padding: 14,
    fontSize: 16,
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
    color: theme.colors.text.primary,
  },
  textArea: {
    minHeight: 100,
    textAlignVertical: 'top',
  },
  button: {
    marginTop: 18,
    backgroundColor: theme.colors.primary,
    borderRadius: 12,
    height: 52,
    justifyContent: 'center',
    alignItems: 'center',
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  buttonText: {
    color: theme.colors.white,
    fontSize: 16,
    fontWeight: '700',
  },
});
