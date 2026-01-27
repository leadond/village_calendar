import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useMutation, useQuery } from 'convex/react';
import { api } from '../convex/_generated/api';
import { useNavigation } from '@react-navigation/native';
import * as Calendar from 'expo-calendar';
import { showSuccess, showError } from '../utils/notifications';
import { triggerSuccessHaptic } from '../utils/haptics';
import { trackRequestDeleted, trackRequestUnclaimed } from '../utils/analytics';
import { Platform } from 'react-native';

import { theme } from '../lib/theme';
import { Ionicons } from '@expo/vector-icons';
import Skeleton from '../components/Skeleton';
import Avatar from '../components/Avatar';

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: theme.colors.background,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    paddingBottom: 10,
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: '700',
    color: theme.colors.text.primary,
  },
  listContent: {
    paddingHorizontal: 20,
    paddingBottom: 100,
  },
  card: {
    backgroundColor: theme.colors.white,
    borderRadius: 12,
    padding: 20,
    marginBottom: 15,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  cardDate: {
    fontSize: 16,
    color: theme.colors.gray.dark,
    fontWeight: '600',
  },
  statusBadge: {
    borderRadius: 20,
    paddingHorizontal: 10,
    paddingVertical: 4,
  },
  statusOpen: {
    backgroundColor: theme.colors.status.openBackground,
  },
  statusClaimed: {
    backgroundColor: theme.colors.status.claimedBackground,
  },
  statusText: {
    fontSize: 12,
    fontWeight: '700',
  },
  statusTextOpen: {
    color: theme.colors.status.open,
  },
  statusTextClaimed: {
    color: theme.colors.status.claimed,
  },
  cardTitle: {
    fontSize: 20,
    fontWeight: '700',
    color: theme.colors.text.primary,
    marginBottom: 5,
  },
  cardDescription: {
    fontSize: 16,
    color: theme.colors.text.secondary,
    marginBottom: 10,
  },
  helperInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 10,
    backgroundColor: theme.colors.primaryLight,
    padding: 8,
    borderRadius: 8,
  },
  helperText: {
    marginLeft: 8,
    fontSize: 15,
    color: theme.colors.primary,
    fontWeight: '600',
  },
  deleteButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: theme.colors.errorLight,
    borderRadius: 8,
    paddingVertical: 12,
    marginTop: 10,
  },
  deleteText: {
    color: theme.colors.accent,
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 8,
  },
  chatButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: theme.colors.primaryExtraLight,
    borderRadius: 8,
    paddingVertical: 12,
    marginTop: 10,
  },
  chatButtonText: {
    color: theme.colors.primary,
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 8,
  },
  cancelButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: theme.colors.gray.light,
    borderRadius: 8,
    paddingVertical: 12,
    marginTop: 10,
  },
  cancelText: {
    color: theme.colors.text.secondary,
    fontSize: 16,
    fontWeight: '600',
  },
  actionRow: {
    flexDirection: 'row',
    marginTop: 10,
    gap: 10,
  },
  actionButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: theme.colors.primaryExtraLight,
    borderRadius: 8,
    paddingVertical: 12,
  },
  actionButtonText: {
    color: theme.colors.primary,
    fontSize: 15,
    fontWeight: '600',
    marginLeft: 8,
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingTop: 50,
  },
  emptyTitle: {
    fontSize: 22,
    fontWeight: '700',
    color: theme.colors.gray.medium,
    marginTop: 20,
    marginBottom: 10,
  },
  emptyText: {
    fontSize: 16,
    color: theme.colors.gray.medium,
    textAlign: 'center',
    paddingHorizontal: 40,
  },
});

interface Props {
  profile: {
    role: 'parent' | 'helper';
    villageId: any;
  };
}

const MyItemSkeleton = () => (
  <View style={styles.card}>
    <View style={styles.cardHeader}>
      <Skeleton width={150} height={20} />
      <Skeleton width={80} height={24} />
    </View>
    <Skeleton width="100%" height={24} style={{ marginVertical: 6 }} />
    <Skeleton width="80%" height={20} />
    <View style={styles.helperInfo}>
      <Skeleton width={120} height={20} />
    </View>
    <Skeleton width="100%" height={44} style={{ marginTop: 10 }} />
  </View>
);

export default function MyItemsScreen({ profile }: Props) {
  const navigation = useNavigation<any>();
  const [isMutating, setIsMutating] = useState<string | null>(null);

  const myRequests = useQuery(api.helpRequests.getMyRequests, profile.role === 'parent' ? {} : 'skip');
  const myClaims = useQuery(api.helpRequests.getMyClaims, profile.role === 'helper' ? {} : 'skip');
  const deleteRequest = useMutation(api.helpRequests.deleteRequest);
  const unclaimRequest = useMutation(api.helpRequests.unclaimRequest);

  const isLoading = profile.role === 'parent' ? myRequests === undefined : myClaims === undefined;

  const handleDelete = (requestId: any) => {
    if (Platform.OS === 'web') {
      if (window.confirm('Are you sure you want to delete this request?')) {
        performDelete(requestId);
      }
    } else {
      Alert.alert('Delete Request', 'Are you sure you want to delete this request?', [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: () => performDelete(requestId),
        },
      ]);
    }
  };

  const performDelete = async (requestId: any) => {
    setIsMutating(requestId);
    try {
      await deleteRequest({ requestId });
      trackRequestDeleted({ villageId: profile.villageId, requestId });
      triggerSuccessHaptic();
      showSuccess('Request deleted');
    } catch (error: any) {
      showError(error.message || 'Failed to delete');
    } finally {
      setIsMutating(null);
    }
  };

  const handleUnclaim = (requestId: any) => {
    if (Platform.OS === 'web') {
      if (window.confirm('Are you sure you can no longer help with this?')) {
        performUnclaim(requestId);
      }
    } else {
      Alert.alert('Cancel Commitment', 'Are you sure you can no longer help with this?', [
        { text: 'Keep', style: 'cancel' },
        {
          text: 'Cancel',
          style: 'destructive',
          onPress: () => performUnclaim(requestId),
        },
      ]);
    }
  };

  const performUnclaim = async (requestId: any) => {
    setIsMutating(requestId);
    try {
      await unclaimRequest({ requestId });
      trackRequestUnclaimed({ villageId: profile.villageId, requestId });
      triggerSuccessHaptic();
      showSuccess('Commitment cancelled');
    } catch (error: any) {
      showError(error.message || 'Failed to unclaim');
    } finally {
      setIsMutating(null);
    }
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

    if (Platform.OS === 'web') {
      const googleCalendarUrl = generateGoogleCalendarUrl(
        item.title,
        item.description,
        startDate,
        endDate,
      );
      window.open(googleCalendarUrl, '_blank');
      showSuccess('Event opened in Google Calendar!');
    } else {
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

        await Calendar.createEventAsync(defaultCal.id, {
          title: `Village: ${item.title}`,
          notes: item.description,
          startDate,
          endDate,
          alarms: [{ relativeOffset: -30 }],
        });

        showSuccess('Event added to your calendar!');
      } catch (error: any) {
        console.error(error);
        showError('Could not add to calendar.');
      }
    }
  };

  const generateGoogleCalendarUrl = (title: string, description: string, startDate: Date, endDate: Date) => {
    const formatDateTime = (date: Date) => date.toISOString().replace(/[-:]|\.\d{3}/g, '').substring(0, 15) + 'Z';

    const params = new URLSearchParams({
      action: 'TEMPLATE',
      text: title,
      dates: `${formatDateTime(startDate)}/${formatDateTime(endDate)}`,
      details: description,
      sf: 'true',
      output: 'xml',
    });
    return `https://calendar.google.com/calendar/render?${params.toString()}`;
  };

  const formatDate = (dateStr: string) => {
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
  };

  const renderParentItem = ({ item }: { item: any }) => (
    <View style={styles.card}>
      <View style={styles.cardHeader}>
        <Text style={styles.cardDate}>
          {formatDate(item.date)} at {item.time}
        </Text>
        <View
          style={[
            styles.statusBadge,
            item.status === 'open' ? styles.statusOpen : styles.statusClaimed,
          ]}
        >
          <Text
            style={[
              styles.statusText,
              item.status === 'open' ? styles.statusTextOpen : styles.statusTextClaimed,
            ]}
          >
            {item.status === 'open' ? 'Open' : 'Claimed'}
          </Text>
        </View>
      </View>

      <Text style={styles.cardTitle}>{item.title}</Text>
      <Text style={styles.cardDescription}>{item.description}</Text>

      {item.claimedByName && (
        <View style={styles.helperInfo}>
          <Avatar name={item.claimedByName} uri={item.claimedByPhotoUrl} size={24} />
          <Text style={styles.helperText}>{item.claimedByName} is helping!</Text>
        </View>
      )}

      {item.status === 'open' && (
        <View style={styles.actionRow}>
          <TouchableOpacity
            style={styles.actionButton}
            onPress={() => navigation.navigate('CreateRequest', { request: item })}
            accessibilityRole="button"
            accessibilityLabel={`Edit request titled ${item.title}`}
          >
            <Ionicons name="create-outline" size={18} color={theme.colors.primary} />
            <Text style={styles.actionButtonText}>Edit</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.actionButton, { backgroundColor: theme.colors.errorLight }]}
            onPress={() => handleDelete(item.id)}
            disabled={isMutating === item.id}
            accessibilityRole="button"
            accessibilityLabel={`Delete request titled ${item.title}`}
          >
            {isMutating === item.id ? (
              <ActivityIndicator color={theme.colors.accent} />
            ) : (
              <>
                <Ionicons name="trash-outline" size={18} color={theme.colors.accent} />
                <Text style={[styles.actionButtonText, { color: theme.colors.accent }]}>Delete</Text>
              </>
            )}
          </TouchableOpacity>
        </View>
      )}

      {item.status === 'claimed' && (
        <TouchableOpacity
          style={styles.chatButton}
          onPress={() => openChat(item, false)}
          accessibilityRole="button"
          accessibilityLabel={`Message helper for request titled ${item.title}`}
        >
          <Ionicons name="chatbubble-outline" size={18} color={theme.colors.primary} />
          <Text style={styles.chatButtonText}>Message Helper</Text>
        </TouchableOpacity>
      )}
    </View>
  );

  const renderHelperItem = ({ item }: { item: any }) => (
    <View style={styles.card}>
      <View style={styles.cardHeader}>
        <Text style={styles.cardDate}>
          {formatDate(item.date)} at {item.time}
        </Text>
        <View style={[styles.statusBadge, styles.statusClaimed]}>
          <Text style={[styles.statusText, styles.statusTextClaimed]}>Committed</Text>
        </View>
      </View>

      <Text style={styles.cardTitle}>{item.title}</Text>
      <Text style={styles.cardDescription}>{item.description}</Text>

      <View style={styles.helperInfo}>
        <Avatar name={item.createdByName} uri={item.createdByPhotoUrl} size={24} />
        <Text style={styles.helperText}>Helping {item.createdByName}</Text>
      </View>

      <TouchableOpacity
        style={styles.cancelButton}
        onPress={() => handleUnclaim(item.id)}
        disabled={isMutating === item.id}
        accessibilityRole="button"
        accessibilityLabel={`Cancel commitment for request titled ${item.title}`}
      >
        {isMutating === item.id ? (
          <ActivityIndicator color={theme.colors.text.secondary} />
        ) : (
          <Text style={styles.cancelText}>I can no longer help</Text>
        )}
      </TouchableOpacity>

      <View style={styles.actionRow}>
        <TouchableOpacity
          style={styles.actionButton}
          onPress={() => handleAddToCalendar(item)}
          accessibilityRole="button"
          accessibilityLabel={`Add request titled ${item.title} to your calendar`}
        >
          <Ionicons name="calendar-outline" size={18} color={theme.colors.primary} />
          <Text style={styles.actionButtonText}>Add to Calendar</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.actionButton}
          onPress={() => openChat(item, true)}
          accessibilityRole="button"
          accessibilityLabel={`Message about request titled ${item.title}`}
        >
          <Ionicons name="chatbubble-outline" size={18} color={theme.colors.primary} />
          <Text style={styles.actionButtonText}>Message</Text>
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

      {isLoading ? (
        <FlatList
          data={[1, 2, 3]}
          renderItem={() => <MyItemSkeleton />}
          keyExtractor={(item) => `skeleton-${item}`}
          contentContainerStyle={styles.listContent}
          getItemLayout={(data, index) => ({
            length: 230,
            offset: 230 * index,
            index,
          })}
          removeClippedSubviews={true}
          maxToRenderPerBatch={5}
          windowSize={10}
          initialNumToRender={3}
          legacyImplementation={false}
        />
      ) : (
        <FlatList
          data={data || []}
          renderItem={profile.role === 'parent' ? renderParentItem : renderHelperItem}
          keyExtractor={(item: any) => `item-${item.id}`}
          contentContainerStyle={styles.listContent}
          getItemLayout={(data, index) => ({
            length: 230,
            offset: 230 * index,
            index,
          })}
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
          removeClippedSubviews={true}
          maxToRenderPerBatch={5}
          windowSize={10}
          initialNumToRender={5}
          legacyImplementation={false}
        />
      )}
    </SafeAreaView>
  );
}
