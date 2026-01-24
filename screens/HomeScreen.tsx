import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  RefreshControl,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useMutation, useQuery } from 'convex/react';
import { api } from '../convex/_generated/api';
import { useNavigation } from '@react-navigation/native';
import { showSuccess } from '../utils/notifications';
import { triggerSuccessHaptic } from '../utils/haptics';
import { trackRequestClaimed } from '../utils/analytics';

import { theme } from '../lib/theme';
import { Ionicons } from '@expo/vector-icons';
import Skeleton from '../components/Skeleton';
interface Props {
  profile: {
    id: string;
    name: string;
    role: 'parent' | 'helper';
    villageId: any;
    villageName: string;
  };
}

const RequestSkeleton = () => (
  <View style={styles.card}>
    <View style={styles.cardHeader}>
      <Skeleton width={150} height={20} />
      <Skeleton width={60} height={20} />
    </View>
    <Skeleton width="100%" height={24} style={{ marginBottom: 6 }} />
    <Skeleton width="80%" height={20} />
    <View style={styles.cardFooter}>
      <Skeleton width={120} height={16} />
    </View>
    <Skeleton width="100%" height={48} style={{ marginTop: 12 }} />
  </View>
);

export default function HomeScreen({ profile }: Props) {
  const navigation = useNavigation<any>();

  const requests = useQuery(api.helpRequests.getVillageRequests, { villageId: profile.villageId });
  const [isClaiming, setIsClaiming] = React.useState<string | null>(null);

  const claimRequest = useMutation(api.helpRequests.claimRequest);

  const handleClaim = async (requestId: any) => {
    if (isClaiming) return;
    setIsClaiming(requestId);
    try {
      await claimRequest({ requestId });
      trackRequestClaimed({ villageId: profile.villageId, requestId });
      triggerSuccessHaptic();
      showSuccess("You're helping out!");
    } catch (error: any) {
      Alert.alert('Error', error?.message || 'Failed to claim request');
    } finally {
      setIsClaiming(null);
    }
  };

  const formatDate = (dateStr: string) => {
    const date = new Date(dateStr);
    const today = new Date();
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    if (date.toDateString() === today.toDateString()) {
      return 'Today';
    } else if (date.toDateString() === tomorrow.toDateString()) {
      return 'Tomorrow';
    } else {
      return date.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
    }
  };

  const renderRequest = ({ item }: { item: any }) => {
    const isOpen = item.status === 'open';
    const canClaim = profile.role === 'helper' && isOpen;
    const canChat = !isOpen && (item.isOwner || item.claimedByName);

    const openChat = () => {
      navigation.navigate('Chat', {
        requestId: item.id,
        requestTitle: item.title,
        requestDate: item.date,
        requestTime: item.time,
        requestDescription: item.description,
        isHelper: !item.isOwner,
      });
    };

    return (
      <View style={[styles.card, !isOpen && styles.cardClaimed]}>
        <View style={styles.cardHeader}>
          <View style={styles.dateTimeContainer}>
            <Ionicons name="calendar-outline" size={16} color={theme.colors.primary} />
            <Text style={styles.dateTime}>
              {formatDate(item.date)} at {item.time}
            </Text>
          </View>
          <View style={[styles.statusBadge, isOpen ? styles.statusOpen : styles.statusClaimed]}>
            <Text style={styles.statusText}>{isOpen ? 'Open' : 'Claimed'}</Text>
          </View>
        </View>

        <Text style={styles.cardTitle}>{item.title}</Text>
        <Text style={styles.cardDescription}>{item.description}</Text>

        <View style={styles.cardFooter}>
          <Text style={styles.postedBy}>Posted by {item.createdByName}</Text>
          {item.claimedByName && <Text style={styles.claimedBy}>Helping: {item.claimedByName}</Text>}
        </View>

        {canClaim && (
          <TouchableOpacity
            style={styles.claimButton}
            onPress={() => handleClaim(item.id)}
            disabled={isClaiming === item.id}
            accessibilityRole="button"
            accessibilityLabel={`I'll help with ${item.title}`}
          >
            {isClaiming === item.id ? (
              <ActivityIndicator color={theme.colors.white} />
            ) : (
              <>
                <Ionicons name="hand-left" size={20} color={theme.colors.white} />
                <Text style={styles.claimButtonText}>I'll Help!</Text>
              </>
            )}
          </TouchableOpacity>
        )}

        {canChat && (
          <TouchableOpacity
            style={styles.chatButton}
            onPress={openChat}
            accessibilityRole="button"
            accessibilityLabel={`Message about ${item.title}`}
          >
            <Ionicons name="chatbubble-outline" size={18} color={theme.colors.primary} />
            <Text style={styles.chatButtonText}>Message</Text>
          </TouchableOpacity>
        )}
      </View>
    );
  };

  const openRequests = requests?.filter((r: any) => r.status === 'open') || [];
  const claimedRequests = requests?.filter((r: any) => r.status === 'claimed') || [];

  if (requests === undefined) {
    return (
      <SafeAreaView style={styles.container} edges={['top']}>
        <View style={styles.header}>
          <View>
            <Text style={styles.greeting}>Hello, {profile.name}!</Text>
            <Text style={styles.villageName}>{profile.villageName}</Text>
          </View>
          <View style={styles.roleBadge}>
            <Ionicons
              name={profile.role === 'parent' ? 'home' : 'heart'}
              size={14}
              color={theme.colors.primary}
            />
            <Text style={styles.roleText}>{profile.role === 'parent' ? 'Parent' : 'Helper'}</Text>
          </View>
        </View>
        <FlatList
          data={[1, 2, 3]}
          renderItem={() => <RequestSkeleton />}
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
        />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <View style={styles.header}>
        <View>
          <Text style={styles.greeting}>Hello, {profile.name}!</Text>
          <Text style={styles.villageName}>{profile.villageName}</Text>
        </View>
        <View style={styles.roleBadge}>
          <Ionicons
            name={profile.role === 'parent' ? 'home' : 'heart'}
            size={14}
            color={theme.colors.primary}
          />
          <Text style={styles.roleText}>{profile.role === 'parent' ? 'Parent' : 'Helper'}</Text>
        </View>
      </View>

      <FlatList
        data={[...openRequests, ...claimedRequests]}
        renderItem={renderRequest}
        keyExtractor={(item: any) => `request-${item.id}`}
        contentContainerStyle={styles.listContent}
        getItemLayout={(data, index) => ({
          length: 230,
          offset: 230 * index,
          index,
        })}
        refreshControl={<RefreshControl refreshing={false} tintColor={theme.colors.primary} />}
        ListHeaderComponent={
          openRequests.length > 0 ? (
            <Text style={styles.sectionTitle}>
              {openRequests.length} request{openRequests.length !== 1 ? 's' : ''} need help
            </Text>
          ) : null
        }
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Ionicons name="heart-outline" size={64} color={theme.colors.gray.medium} />
            <Text style={styles.emptyTitle}>No requests yet</Text>
            <Text style={styles.emptyText}>
              {profile.role === 'parent'
                ? 'Tap the + button to create your first help request'
                : 'Check back soon for help requests from parents'}
            </Text>
          </View>
        }
        removeClippedSubviews={true}
        maxToRenderPerBatch={5}
        windowSize={10}
        initialNumToRender={5}
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
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    borderBottomWidth: 1,
    borderBottomColor: theme.colors.gray.light,
  },
  greeting: {
    fontSize: theme.fontSizes.xl,
    fontWeight: 'bold',
    color: theme.colors.text.primary,
  },
  villageName: {
    fontSize: theme.fontSizes.sm,
    color: theme.colors.text.secondary,
    marginTop: 2,
  },
  roleBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: theme.colors.background,
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
    gap: 4,
  },
  roleText: {
    fontSize: theme.fontSizes.xs,
    color: theme.colors.primary,
    fontWeight: '500',
  },
  listContent: {
    padding: 16,
    paddingBottom: 100,
  },
  sectionTitle: {
    fontSize: theme.fontSizes.lg,
    fontWeight: '600',
    color: theme.colors.text.primary,
    marginBottom: 12,
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
  cardClaimed: {
    opacity: 0.7,
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  dateTimeContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  dateTime: {
    fontSize: theme.fontSizes.sm,
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
    fontSize: theme.fontSizes.xs,
    fontWeight: '600',
  },
  cardTitle: {
    fontSize: theme.fontSizes.lg,
    fontWeight: '600',
    color: theme.colors.text.primary,
    marginBottom: 6,
  },
  cardDescription: {
    fontSize: theme.fontSizes.sm,
    color: theme.colors.text.secondary,
    lineHeight: 22,
    marginBottom: 12,
  },
  cardFooter: {
    borderTopWidth: 1,
    borderTopColor: theme.colors.gray.light,
    paddingTop: 12,
  },
  postedBy: {
    fontSize: theme.fontSizes.xs,
    color: theme.colors.text.secondary,
  },
  claimedBy: {
    fontSize: theme.fontSizes.xs,
    color: theme.colors.status.claimed,
    fontWeight: '500',
    marginTop: 4,
  },
  claimButton: {
    backgroundColor: theme.colors.primary,
    borderRadius: 12,
    height: 48,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 12,
    gap: 8,
  },
  claimButtonText: {
    color: theme.colors.white,
    fontSize: theme.fontSizes.md,
    fontWeight: '600',
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
    fontSize: theme.fontSizes.sm,
    fontWeight: '600',
  },
  emptyContainer: {
    alignItems: 'center',
    paddingVertical: 60,
  },
  emptyTitle: {
    fontSize: theme.fontSizes.xl,
    fontWeight: '600',
    color: theme.colors.text.primary,
    marginTop: 16,
  },
  emptyText: {
    fontSize: theme.fontSizes.sm,
    color: theme.colors.text.secondary,
    textAlign: 'center',
    marginTop: 8,
    paddingHorizontal: 32,
    lineHeight: 22,
  },
});