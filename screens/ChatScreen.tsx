import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TextInput,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
  Alert,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useMutation, useQuery } from 'convex/react';
import { api } from '../convex/_generated/api';
import { Ionicons } from '@expo/vector-icons';
import { theme } from '../lib/theme';
import * as Calendar from 'expo-calendar';

interface Props {
  route: {
    params: {
      requestId: any;
      requestTitle: string;
      requestDate: string;
      requestTime: string;
      requestDescription: string;
      isHelper: boolean;
    };
  };
  navigation: any;
}

export default function ChatScreen({ route, navigation }: Props) {
  const { requestId, requestTitle, requestDate, requestTime, requestDescription, isHelper } = route.params;
  const messages = useQuery(api.messages.getMessages, { requestId });
  const sendMessage = useMutation(api.messages.sendMessage);

  const [text, setText] = useState('');
  const [sending, setSending] = useState(false);
  const flatListRef = useRef<FlatList<any>>(null);

  useEffect(() => {
    if (messages && messages.length > 0) {
      setTimeout(() => {
        flatListRef.current?.scrollToEnd({ animated: true });
      }, 100);
    }
  }, [messages?.length]);

  const handleSend = async () => {
    if (!text.trim() || sending) return;

    setSending(true);
    try {
      await sendMessage({ requestId, text: text.trim() });
      setText('');
    } catch (error: any) {
      Alert.alert('Error', error?.message ?? 'Failed to send');
    } finally {
      setSending(false);
    }
  };

  const handleAddToCalendar = async () => {
    try {
      const { status } = await Calendar.requestCalendarPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission Required', 'Calendar access is needed to add events.');
        return;
      }

      const calendars = await Calendar.getCalendarsAsync(Calendar.EntityTypes.EVENT);
      const writableCalendars = calendars.filter(
        (cal: any) => cal.allowsModifications && cal.source.name !== 'Birthdays'
      );

      if (writableCalendars.length === 0) {
        Alert.alert('No Calendar', 'No writable calendar found on this device.');
        return;
      }

      // Use default or first writable calendar
      const defaultCal =
        writableCalendars.find((c: any) => c.isPrimary) ||
        writableCalendars.find((c: any) => c.source.name === 'iCloud') ||
        writableCalendars[0];

      // Parse date and time
      const [year, month, day] = requestDate.split('-').map(Number);
      const timeMatch = requestTime.match(/(\d{1,2}):?(\d{2})?\s*(AM|PM)?/i);
      let hours = 9;
      let minutes = 0;

      if (timeMatch) {
        hours = parseInt(timeMatch[1], 10);
        minutes = parseInt(timeMatch[2] || '0', 10);
        const meridiem = timeMatch[3]?.toUpperCase();
        if (meridiem === 'PM' && hours < 12) hours += 12;
        if (meridiem === 'AM' && hours === 12) hours = 0;
      }

      const startDate = new Date(year, month - 1, day, hours, minutes);
      const endDate = new Date(startDate.getTime() + 60 * 60 * 1000); // 1 hour

      await Calendar.createEventAsync(defaultCal.id, {
        title: `Village: ${requestTitle}`,
        notes: requestDescription,
        startDate,
        endDate,
        alarms: [{ relativeOffset: -30 }], // 30 min reminder
      });

      Alert.alert('Added!', 'Event added to your calendar with a 30-minute reminder.');
    } catch (error: any) {
      console.error(error);
      Alert.alert('Error', 'Could not add to calendar.');
    }
  };

  const formatTime = (ts: number) => {
    const d = new Date(ts);
    return d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
  };

  const renderMessage = ({ item }: { item: any }) => (
    <View style={[styles.messageBubble, item.isMe ? styles.myMessage : styles.theirMessage]}>
      {!item.isMe && <Text style={styles.senderName}>{item.senderName}</Text>}
      <Text style={[styles.messageText, item.isMe && styles.myMessageText]}>{item.text}</Text>
      <Text style={[styles.messageTime, item.isMe && styles.myMessageTime]}>
        {formatTime(item.createdAt)}
      </Text>
    </View>
  );

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <View style={styles.header}>
        <TouchableOpacity style={styles.backBtn} onPress={() => navigation.goBack()}>
          <Ionicons name="chevron-back" size={22} color={theme.colors.text.primary} />
        </TouchableOpacity>
        <View style={styles.headerInfo}>
          <Text style={styles.headerTitle} numberOfLines={1}>
            {requestTitle}
          </Text>
          <Text style={styles.headerSubtitle}>
            {requestDate} at {requestTime}
          </Text>
        </View>
        {isHelper && (
          <TouchableOpacity style={styles.calendarBtn} onPress={handleAddToCalendar}>
            <Ionicons name="calendar-outline" size={22} color={theme.colors.primary} />
          </TouchableOpacity>
        )}
      </View>

      <KeyboardAvoidingView
        style={styles.content}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        keyboardVerticalOffset={0}
      >
        <FlatList
          ref={flatListRef}
          data={messages ?? []}
          keyExtractor={(item: any) => item.id}
          renderItem={renderMessage}
          contentContainerStyle={styles.messageList}
          ListEmptyComponent={
            <View style={styles.emptyContainer}>
              <Ionicons name="chatbubbles-outline" size={48} color={theme.colors.gray.medium} />
              <Text style={styles.emptyTitle}>Start the conversation</Text>
              <Text style={styles.emptyText}>
                Coordinate details, share updates, or ask questions about this request.
              </Text>
            </View>
          }
        />

        <View style={styles.inputContainer}>
          <TextInput
            style={styles.input}
            placeholder="Type a message..."
            placeholderTextColor={theme.colors.gray.medium}
            value={text}
            onChangeText={setText}
            multiline
            maxLength={500}
          />
          <TouchableOpacity
            style={[styles.sendBtn, (!text.trim() || sending) && styles.sendBtnDisabled]}
            onPress={handleSend}
            disabled={!text.trim() || sending}
          >
            <Ionicons
              name="send"
              size={20}
              color={text.trim() && !sending ? theme.colors.white : theme.colors.gray.medium}
            />
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
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
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: theme.colors.white,
    borderBottomWidth: 1,
    borderBottomColor: theme.colors.gray.light,
    gap: 12,
  },
  backBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: theme.colors.background,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
  },
  headerInfo: {
    flex: 1,
  },
  headerTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: theme.colors.text.primary,
  },
  headerSubtitle: {
    marginTop: 2,
    fontSize: 13,
    color: theme.colors.text.secondary,
  },
  calendarBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: theme.colors.primary + '15',
    alignItems: 'center',
    justifyContent: 'center',
  },
  content: {
    flex: 1,
  },
  messageList: {
    padding: 16,
    paddingBottom: 8,
    flexGrow: 1,
  },
  emptyContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 60,
    paddingHorizontal: 32,
  },
  emptyTitle: {
    marginTop: 16,
    fontSize: 18,
    fontWeight: '600',
    color: theme.colors.text.primary,
  },
  emptyText: {
    marginTop: 8,
    fontSize: 14,
    color: theme.colors.text.secondary,
    textAlign: 'center',
    lineHeight: 20,
  },
  messageBubble: {
    maxWidth: '80%',
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 18,
    marginBottom: 8,
  },
  myMessage: {
    alignSelf: 'flex-end',
    backgroundColor: theme.colors.primary,
    borderBottomRightRadius: 4,
  },
  theirMessage: {
    alignSelf: 'flex-start',
    backgroundColor: theme.colors.white,
    borderBottomLeftRadius: 4,
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
  },
  senderName: {
    fontSize: 12,
    fontWeight: '600',
    color: theme.colors.primary,
    marginBottom: 4,
  },
  messageText: {
    fontSize: 15,
    color: theme.colors.text.primary,
    lineHeight: 20,
  },
  myMessageText: {
    color: theme.colors.white,
  },
  messageTime: {
    marginTop: 4,
    fontSize: 11,
    color: theme.colors.text.secondary,
    alignSelf: 'flex-end',
  },
  myMessageTime: {
    color: 'rgba(255,255,255,0.7)',
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: theme.colors.white,
    borderTopWidth: 1,
    borderTopColor: theme.colors.gray.light,
    gap: 10,
  },
  input: {
    flex: 1,
    minHeight: 40,
    maxHeight: 100,
    backgroundColor: theme.colors.background,
    borderRadius: 20,
    paddingHorizontal: 16,
    paddingVertical: 10,
    fontSize: 15,
    color: theme.colors.text.primary,
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
  },
  sendBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: theme.colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sendBtnDisabled: {
    backgroundColor: theme.colors.gray.light,
  },
});