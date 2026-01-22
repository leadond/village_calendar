import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  Alert,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useMutation, useQuery } from 'convex/react';
import { api } from '../convex/_generated/api';
import { useNavigation } from '@react-navigation/native';
import * as Calendar from 'expo-calendar';

import { theme } from '../lib/theme';
import { Ionicons } from '@expo/vector-icons';

interface Props {
  profile: {
    role: 'parent' | 'helper';
  };
}

export default function MyItemsScreen({ profile }: Props) {
  const navigation = useNavigation<any>();
  const myRequests = useQuery(api.helpRequests.getMyRequests, profile.role === 'parent' ? {} : 'skip');
  const myClaims = useQuery(api.helpRequests.getMyClaims, profile.role === 'helper' ? {} : 'skip');
  const deleteRequest = useMutation(api.helpRequests.deleteRequest);
  const unclaimRequest = useMutation(api.helpRequests.unclaimRequest);

  const handleDelete = (requestId: any) => {
    Alert.alert('Delete Request', 'Are you sure you want to delete this request?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          try {
            await deleteRequest({ requestId });
          } catch (error: any) {
            Alert.alert('Error', error?.message || 'Failed to delete');
          }
        },
      },
    ]);
  };

  const handleUnclaim = (requestId: any) => {
    Alert.alert('Cancel Commitment', 'Are you sure you can no longer help with this?', [
      { text: 'Keep', style: 'cancel' },
      {
        text: 'Cancel',
        style: 'destructive',
        onPress: async () => {
          try {
            await unclaimRequest({ requestId });
          } catch (error: any) {
            Alert.alert('Error', error?.message || 'Failed to unclaim');
          }
        },
      },
    ]);
  };

  const openChat = (item: any, isHelper: boolean) => {
    navigation.navigate('Chat', {
      requestId: item.id,
      requestTitle: item.title,
      requestDate: item.date,
      requestTime: item.time,
      requestDescription: item.description,
      isHelper,
    });
  };

  const handleAddToCalendar = async (item: any) => {
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

      const defaultCal =
        writableCalendars.find((c: any) => c.isPrimary) ||
        writableCalendars.find((c: any) => c.source.name === 'iCloud') ||
        writableCalendars[0];

      const [year, month, day] = item.date.split('-').map(Number);
      const timeMatch = item.time.match(/(\d{1,2}):?(\d{2})?\s*(AM|PM)?/i);
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
      const endDate = new Date(startDate.getTime() + 60 * 60 * 1000);

      await Calendar.createEventAsync(defaultCal.id, {
        title: `Village: ${item.title}`,
        notes: item.description,
        startDate,
        endDate,
        alarms: [{ relativeOffset: -30 }],
      });

      Alert.alert('Added!', 'Event added to your calendar with a 30-minute reminder.');
    } catch (error: any) {
      console.error(error);
      Alert.alert('Error', 'Could not add to calendar.');
    }
  };

  const formatDate = (dateStr: string) => {
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
  };

  const renderParentItem = ({ item }: { item: any }) => (
    <View style={styles.card}>
      <View style={styles.cardHeader}>
        <Text style={styles.cardDate}>{formatDate(item.date)} at {item.time}</Text>
        <View style={[styles.statusBadge, item.status === 'open' ? styles.statusOpen : styles.statusClaimed]}>
          <Text style={[styles.statusText, item.status === 'open' ? styles.statusTextOpen : styles.statusTextClaimed]}>
            {item.status === 'open' ? 'Open' : 'Claimed'}
          </Text>
        </View>
      </View>

      <Text style={styles.cardTitle}>{item.title}</Text>
      <Text style={styles.cardDescription}>{item.description}</Text>

      {item.claimedByName && (
        <View style={styles.helperInfo}>
          <Ionicons name="person-circle" size={20} color={theme.colors.status.claimed} />
          <Text style={styles.helperText}>{item.claimedByName} is helping!</Text>
        </View>
      )}

      {item.status === 'open' && (
        <TouchableOpacity style={styles.deleteButton} onPress={() => handleDelete(item.id)}>
          <Ionicons name="trash-outline" size={18} color={theme.colors.accent} />
          <Text style={styles.deleteText}>Delete</Text>
        </TouchableOpacity>
      )}

      {item.status === 'claimed' && (
        <TouchableOpacity style={styles.chatButton} onPress={() => openChat(item, false)}>
          <Ionicons name="chatbubble-outline" size={18} color={theme.colors.primary} />
          <Text style={styles.chatButtonText}>Message Helper</Text>
        </TouchableOpacity>
      )}
    </View>
  );

  const renderHelperItem = ({ item }: { item: any }) => (
    <View style={styles.card}>
      <View style={styles.cardHeader}>
        <Text style={styles.cardDate}>{formatDate(item.date)} at {item.time}</Text>
        <View style={[styles.statusBadge, styles.statusClaimed]}>
          <Text style={[styles.statusText, styles.statusTextClaimed]}>Committed</Text>
        </View>
      </View>

      <Text style={styles.cardTitle}>{item.title}</Text>
      <Text style={styles.cardDescription}>{item.description}</Text>

      <View style={styles.helperInfo}>
        <Ionicons name="person-circle" size={20} color={theme.colors.primary} />
        <Text style={styles.helperText}>Helping {item.createdByName}</Text>
      </View>

      <TouchableOpacity style={styles.cancelButton} onPress={() => handleUnclaim(item.id)}>
        <Text style={styles.cancelText}>I can no longer help</Text>
      </TouchableOpacity>

      <View style={styles.actionRow}>
        <TouchableOpacity style={styles.actionButton} onPress={() => openChat(item, true)}>
          <Ionicons name="chatbubble-outline" size={18} color={theme.colors.primary} />
          <Text style={styles.actionButtonText}>Message</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.actionButton} onPress={() => handleAddToCalendar(item)}>
          <Ionicons name="calendar-outline" size={18} color={theme.colors.primary} />
          <Text style={styles.actionButtonText}>Add to Calendar</Text>
        </TouchableOpacity>
      </View>
    </View>
  );

  const data = profile.role === 'parent' ? myRequests : myClaims;
  const isEmpty = !data || data.length === 0;

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>
          {profile.role === 'parent' ? 'My Requests' : 'My Commitments'}
        </Text>
      </View>

      <FlatList
        data={data || []}
        renderItem={profile.role === 'parent' ? renderParentItem : renderHelperItem}
        keyExtractor={(item: any) => item.id}
        contentContainerStyle={styles.listContent}
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Ionicons
              name={profile.role === 'parent' ? 'document-text-outline' : 'hand-left-outline'}
              size={64}
              color={theme.colors.gray.medium}
            />
            <Text style={styles.emptyTitle}>
              {profile.role === 'parent' ? 'No requests yet' : 'No commitments yet'}
            </Text>
            <Text style={styles.emptyText}>
              {profile.role === 'parent'
                ? 'Create a help request to get started'
                : 'Browse open requests and volunteer to help'}
            </Text>
          </View>
        }
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: theme.colors.background,
  },
  header: {
    padding: 20,
    paddingBottom: 16,
    backgroundColor: theme.colors.white,
    borderBottomWidth: 1,
    borderBottomColor: theme.colors.gray.light,
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: theme.colors.text.primary,
  },
  listContent: {
    padding: 16,
    paddingBottom: 100,
  },
  card: {
    backgroundColor: theme.colors.white,
    borderRadius: 16,
    padding: 16,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.06,
    shadowRadius: 8,
    elevation: 2,
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  cardDate: {
    fontSize: 14,
    color: theme.colors.primary,
    fontWeight: '500',
  },
  statusBadge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 12,
  },
  statusOpen: {
    backgroundColor: theme.colors.accent + '20',
  },
  statusClaimed: {
    backgroundColor: theme.colors.status.claimed + '20',
  },
  statusText: {
    fontSize: 12,
    fontWeight: '600',
  },
  statusTextOpen: {
    color: theme.colors.accent,
  },
  statusTextClaimed: {
    color: theme.colors.status.claimed,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: theme.colors.text.primary,
    marginBottom: 6,
  },
  cardDescription: {
    fontSize: 15,
    color: theme.colors.text.secondary,
    lineHeight: 22,
  },
  helperInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 12,
    gap: 6,
  },
  helperText: {
    fontSize: 14,
    color: theme.colors.status.claimed,
    fontWeight: '500',
  },
  deleteButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 12,
    paddingVertical: 10,
    borderTopWidth: 1,
    borderTopColor: theme.colors.gray.light,
    gap: 6,
  },
  deleteText: {
    fontSize: 14,
    color: theme.colors.accent,
    fontWeight: '500',
  },
  cancelButton: {
    alignItems: 'center',
    marginTop: 12,
    paddingVertical: 10,
    borderTopWidth: 1,
    borderTopColor: theme.colors.gray.light,
  },
  cancelText: {
    fontSize: 14,
    color: theme.colors.text.secondary,
  },
  chatButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: theme.colors.primary + '15',
    borderRadius: 12,
    height: 44,
    marginTop: 10,
    gap: 8,
  },
  chatButtonText: {
    color: theme.colors.primary,
    fontSize: 15,
    fontWeight: '600',
  },
  actionRow: {
    flexDirection: 'row',
    gap: 10,
    marginTop: 10,
  },
  actionButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: theme.colors.primary + '15',
    borderRadius: 12,
    height: 44,
    gap: 6,
  },
  actionButtonText: {
    color: theme.colors.primary,
    fontSize: 14,
    fontWeight: '600',
  },
  emptyContainer: {
    alignItems: 'center',
    paddingVertical: 60,
  },
  emptyTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: theme.colors.text.primary,
    marginTop: 16,
  },
  emptyText: {
    fontSize: 15,
    color: theme.colors.text.secondary,
    textAlign: 'center',
    marginTop: 8,
    paddingHorizontal: 32,
    lineHeight: 22,
  },
});