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
import { useMutation } from 'convex/react';
import { api } from '../convex/_generated/api';
import { showSuccess } from '../utils/notifications';
import { triggerSuccessHaptic } from '../utils/haptics';
import { trackRequestCreated } from '../utils/analytics';

import { theme } from '../lib/theme';
import { Ionicons } from '@expo/vector-icons';
interface Props {
  profile: {
    villageId: any;
  };
  navigation: any;
}

export default function CreateRequestScreen({ profile, navigation, route }: Props & { route: any }) {
  const createRequest = useMutation(api.helpRequests.createRequest);
  const updateRequest = useMutation(api.helpRequests.updateRequest);

  const editingRequest = route?.params?.request;
  const isEditing = !!editingRequest;

  const [title, setTitle] = useState(editingRequest?.title || '');
  const [description, setDescription] = useState(editingRequest?.description || '');
  const [date, setDate] = useState(editingRequest?.date || '');
  const [time, setTime] = useState(editingRequest?.time || '');
  const [saving, setSaving] = useState(false);

  // Simple date picker using text input with format hint
  const todayStr = new Date().toISOString().split('T')[0];

  const handleCreate = async () => {
    if (!title.trim()) {
      Alert.alert('Error', 'Please enter a title');
      return;
    }
    if (!description.trim()) {
      Alert.alert('Error', 'Please describe what you need help with');
      return;
    }
    if (!date) {
      Alert.alert('Error', 'Please select a date');
      return;
    }
    if (!time) {
      Alert.alert('Error', 'Please enter a time');
      return;
    }

    setSaving(true);
    try {
      if (isEditing) {
        await updateRequest({
          requestId: editingRequest.id,
          title: title.trim(),
          description: description.trim(),
          date,
          time,
        });
        triggerSuccessHaptic();
        showSuccess('Request updated!');
      } else {
        const requestId = await createRequest({
          villageId: profile.villageId,
          title: title.trim(),
          description: description.trim(),
          date,
          time,
        });
        trackRequestCreated({ villageId: profile.villageId, requestId });
        triggerSuccessHaptic();
        showSuccess('Your help request has been posted!');
      }
      navigation.goBack();
    } catch (error: any) {
      Alert.alert('Error', error?.message || 'Failed to save request');
      setSaving(false);
    }
  };

  const quickDates = [
    { label: 'Today', value: todayStr },
    {
      label: 'Tomorrow',
      value: new Date(Date.now() + 86400000).toISOString().split('T')[0],
    },
    {
      label: 'This Weekend',
      value: (() => {
        const d = new Date();
        d.setDate(d.getDate() + ((6 - d.getDay()) % 7 || 7));
        return d.toISOString().split('T')[0];
      })(),
    },
  ];

  const quickTimes = ['9:00 AM', '12:00 PM', '3:00 PM', '6:00 PM'];

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <View style={styles.header}>
        <TouchableOpacity
          onPress={() => navigation.goBack()}
          style={styles.closeButton}
          accessibilityLabel="Close screen"
          accessibilityHint="Return to the previous screen"
          accessibilityRole="button"
        >
          <Ionicons name="close" size={28} color={theme.colors.text.primary} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>{isEditing ? 'Edit Request' : 'New Request'}</Text>
        <View style={{ width: 44 }} />
      </View>

      <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
        <Text style={styles.label}>What do you need help with?</Text>
        <TextInput
          style={styles.input}
          placeholder="e.g., School pickup, Babysitting"
          value={title}
          onChangeText={setTitle}
          placeholderTextColor={theme.colors.gray.medium}
          accessibilityLabel="Request title"
          accessibilityHint="Enter a brief title for your help request"
        />

        <Text style={styles.label}>Details</Text>
        <TextInput
          style={[styles.input, styles.textArea]}
          placeholder="Describe the help you need, any special instructions, etc."
          value={description}
          onChangeText={setDescription}
          multiline
          numberOfLines={4}
          textAlignVertical="top"
          placeholderTextColor={theme.colors.gray.medium}
          accessibilityLabel="Request details"
          accessibilityHint="Provide detailed description of what help you need"
        />

        <Text style={styles.label}>When do you need help?</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.quickPicker}>
          {quickDates.map((d) => (
            <TouchableOpacity
              key={d.value}
              style={[styles.quickButton, date === d.value && styles.quickButtonSelected]}
              onPress={() => setDate(d.value)}
              accessibilityLabel={`Select ${d.label}`}
              accessibilityHint={`Set date to ${d.label}`}
              accessibilityRole="button"
            >
              <Text style={[styles.quickButtonText, date === d.value && styles.quickButtonTextSelected]}>
                {d.label}
              </Text>
            </TouchableOpacity>
          ))}
        </ScrollView>

        <TextInput
          style={styles.input}
          placeholder="Or enter date (YYYY-MM-DD)"
          value={date}
          onChangeText={setDate}
          placeholderTextColor={theme.colors.gray.medium}
        />

        <Text style={styles.label}>What time?</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.quickPicker}>
          {quickTimes.map((t) => (
            <TouchableOpacity
              key={t}
              style={[styles.quickButton, time === t && styles.quickButtonSelected]}
              onPress={() => setTime(t)}
              accessibilityLabel={`Select time ${t}`}
              accessibilityHint={`Set time to ${t}`}
              accessibilityRole="button"
            >
              <Text style={[styles.quickButtonText, time === t && styles.quickButtonTextSelected]}>
                {t}
              </Text>
            </TouchableOpacity>
          ))}
        </ScrollView>

        <TextInput
          style={styles.input}
          placeholder="Or enter custom time"
          value={time}
          onChangeText={setTime}
          placeholderTextColor={theme.colors.gray.medium}
        />

        <TouchableOpacity
          style={[styles.submitButton, saving && styles.submitButtonDisabled]}
          onPress={handleCreate}
          disabled={saving}
          accessibilityLabel={isEditing ? "Save changes" : "Post request"}
          accessibilityHint="Submit your changes"
          accessibilityRole="button"
        >
          {saving ? (
            <ActivityIndicator color={theme.colors.white} />
          ) : (
            <>
              <Ionicons name={isEditing ? "save-outline" : "paper-plane"} size={20} color={theme.colors.white} />
              <Text style={styles.submitButtonText}>{isEditing ? 'Save Changes' : 'Post Request'}</Text>
            </>
          )}
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
    padding: 16,
    backgroundColor: theme.colors.white,
    borderBottomWidth: 1,
    borderBottomColor: theme.colors.gray.light,
  },
  closeButton: {
    width: 44,
    height: 44,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: theme.colors.text.primary,
  },
  content: {
    flex: 1,
    padding: 20,
  },
  label: {
    fontSize: 16,
    fontWeight: '600',
    color: theme.colors.text.primary,
    marginBottom: 8,
    marginTop: 16,
  },
  input: {
    backgroundColor: theme.colors.white,
    borderRadius: 12,
    padding: 16,
    fontSize: 16,
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
  },
  textArea: {
    minHeight: 100,
    paddingTop: 16,
  },
  quickPicker: {
    marginBottom: 12,
  },
  quickButton: {
    backgroundColor: theme.colors.white,
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 20,
    marginRight: 8,
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
  },
  quickButtonSelected: {
    backgroundColor: theme.colors.primary,
    borderColor: theme.colors.primary,
  },
  quickButtonText: {
    fontSize: 14,
    color: theme.colors.text.primary,
    fontWeight: '500',
  },
  quickButtonTextSelected: {
    color: theme.colors.white,
  },
  submitButton: {
    backgroundColor: theme.colors.primary,
    borderRadius: 12,
    height: 52,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 32,
    marginBottom: 40,
    gap: 8,
  },
  submitButtonDisabled: {
    opacity: 0.7,
  },
  submitButtonText: {
    color: theme.colors.white,
    fontSize: 17,
    fontWeight: '600',
  },
});