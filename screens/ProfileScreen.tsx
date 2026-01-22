import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
  Share,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useAuthActions } from '@convex-dev/auth/react';
import { useMutation, useQuery } from 'convex/react';
import { api } from '../convex/_generated/api';

import { theme } from '../lib/theme';
import { Ionicons } from '@expo/vector-icons';

interface Props {
  profile: {
    name: string;
    role: 'parent' | 'helper';
    villageId: any;
    villageName: string;
    villageCode: string;
  };
  navigation?: any;
}

export default function ProfileScreen({ profile, navigation }: Props) {
  const [sharingInvite, setSharingInvite] = useState(false);
  const { signOut } = useAuthActions();
  const members = useQuery(api.villages.getVillageMembers, { villageId: profile.villageId });
  const adminStatus = useQuery(api.adminAuth.getAdminStatus, {});
  const bootstrapOwner = useMutation(api.adminAuth.bootstrapOwner);
  const createInvite = useMutation(api.invites.createInvite);

  const handleShareInvite = async () => {
    try {
      if (sharingInvite) return;
      setSharingInvite(true);

      const invite = await createInvite({ villageId: profile.villageId });

      const url = 'https://a0.dev/app/f3e1f932-1508-4895-9ece-4fc1a163c829';
      const message = `You're invited to join "${invite.villageName}" on Village Calendar!\n\nDownload: ${url}\n\nInvite Code: ${invite.code}\n\nOpen the app → Sign up → Enter this invite code to join.`;

      await Share.share({
        title: 'Village Calendar Invite',
        message,
        url,
      });
    } catch (error: any) {
      console.error(error);
      Alert.alert('Invite failed', error?.message ?? 'Could not create/share invite');
    } finally {
      setSharingInvite(false);
    }
  };

  const handleLogout = () => {
    Alert.alert('Sign Out', 'Are you sure you want to sign out?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Sign Out',
        style: 'destructive',
        onPress: () => {
          signOut();
        }
      },
    ]);
  };

  const handleBootstrapOwner = () => {
    Alert.alert(
      'Claim owner access?',
      'This device/user will become the app owner admin. This can only be done once (first admin).',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Claim Owner',
          style: 'default',
          onPress: async () => {
            try {
              await bootstrapOwner({});
            } catch (e: any) {
              Alert.alert('Error', e?.message ?? 'Failed');
            }
          },
        },
      ]
    );
  };

  const parents = members?.filter((m: any) => m.role === 'parent') || [];
  const helpers = members?.filter((m: any) => m.role === 'helper') || [];

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Profile</Text>
      </View>

      <View style={styles.content}>
        {/* User Info */}
        <View style={styles.userSection}>
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>{profile.name.charAt(0).toUpperCase()}</Text>
          </View>
          <Text style={styles.userName}>{profile.name}</Text>
          <View style={styles.roleBadge}>
            <Ionicons
              name={profile.role === 'parent' ? 'home' : 'heart'}
              size={14}
              color={theme.colors.white}
            />
            <Text style={styles.roleText}>{profile.role === 'parent' ? 'Parent' : 'Helper'}</Text>
          </View>
        </View>

        {/* Village Info */}
        <View style={styles.villageSection}>
          <Text style={styles.sectionTitle}>My Village</Text>
          <View style={styles.villageCard}>
            <View style={styles.villageHeader}>
              <Text style={styles.villageName}>{profile.villageName}</Text>
              <TouchableOpacity
                style={styles.shareButton}
                onPress={handleShareInvite}
                disabled={sharingInvite}
              >
                <Ionicons
                  name={sharingInvite ? 'time-outline' : 'share-outline'}
                  size={20}
                  color={sharingInvite ? theme.colors.gray.medium : theme.colors.primary}
                />
              </TouchableOpacity>
            </View>

            <View style={styles.codeContainer}>
              <Text style={styles.codeLabel}>Village Code (Admin)</Text>
              <Text style={styles.codeValue}>{profile.villageCode}</Text>
            </View>

            <View style={styles.membersRow}>
              <View style={styles.memberStat}>
                <Ionicons name="home" size={18} color={theme.colors.primary} />
                <Text style={styles.memberCount}>{parents.length} parent{parents.length !== 1 ? 's' : ''}</Text>
              </View>
              <View style={styles.memberStat}>
                <Ionicons name="heart" size={18} color={theme.colors.accent} />
                <Text style={styles.memberCount}>{helpers.length} helper{helpers.length !== 1 ? 's' : ''}</Text>
              </View>
            </View>
          </View>
        </View>

        {/* Actions */}
        <View style={styles.actionsSection}>
          {adminStatus?.role ? (
            <TouchableOpacity
              style={styles.actionButton}
              onPress={() => navigation?.navigate?.('Admin')}
            >
              <Ionicons name="analytics-outline" size={22} color={theme.colors.text.primary} />
              <Text style={styles.actionText}>Admin Tools</Text>
              <Ionicons name="chevron-forward" size={20} color={theme.colors.gray.medium} />
            </TouchableOpacity>
          ) : adminStatus && !adminStatus.hasAnyAdmin ? (
            <TouchableOpacity style={styles.actionButton} onPress={handleBootstrapOwner}>
              <Ionicons name="key-outline" size={22} color={theme.colors.text.primary} />
              <Text style={styles.actionText}>Claim Owner Access</Text>
              <Ionicons name="chevron-forward" size={20} color={theme.colors.gray.medium} />
            </TouchableOpacity>
          ) : null}

          <TouchableOpacity style={styles.actionButton} onPress={handleShareInvite} disabled={sharingInvite}>
            <Ionicons name="person-add-outline" size={22} color={theme.colors.text.primary} />
            <Text style={styles.actionText}>Invite to Village</Text>
            <Ionicons name="chevron-forward" size={20} color={theme.colors.gray.medium} />
          </TouchableOpacity>

          <TouchableOpacity style={[styles.actionButton, styles.logoutButton]} onPress={handleLogout}>
            <Ionicons name="log-out-outline" size={22} color={theme.colors.accent} />
            <Text style={[styles.actionText, styles.logoutText]}>Sign Out</Text>
          </TouchableOpacity>
        </View>
      </View>
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
  content: {
    flex: 1,
    padding: 20,
  },
  userSection: {
    alignItems: 'center',
    marginBottom: 32,
  },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: theme.colors.primary,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 12,
  },
  avatarText: {
    fontSize: 32,
    fontWeight: 'bold',
    color: theme.colors.white,
  },
  userName: {
    fontSize: 24,
    fontWeight: '600',
    color: theme.colors.text.primary,
    marginBottom: 8,
  },
  roleBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: theme.colors.primary,
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 16,
    gap: 6,
  },
  roleText: {
    fontSize: 14,
    color: theme.colors.white,
    fontWeight: '500',
  },
  villageSection: {
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: theme.colors.text.primary,
    marginBottom: 12,
  },
  villageCard: {
    backgroundColor: theme.colors.white,
    borderRadius: 16,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.06,
    shadowRadius: 8,
    elevation: 2,
  },
  villageHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  villageName: {
    fontSize: 20,
    fontWeight: '600',
    color: theme.colors.text.primary,
  },
  shareButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: theme.colors.background,
    justifyContent: 'center',
    alignItems: 'center',
  },
  codeContainer: {
    backgroundColor: theme.colors.background,
    borderRadius: 12,
    padding: 12,
    alignItems: 'center',
    marginBottom: 16,
  },
  codeLabel: {
    fontSize: 12,
    color: theme.colors.text.secondary,
    marginBottom: 4,
  },
  codeValue: {
    fontSize: 24,
    fontWeight: 'bold',
    color: theme.colors.primary,
    letterSpacing: 4,
  },
  membersRow: {
    flexDirection: 'row',
    gap: 24,
  },
  memberStat: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  memberCount: {
    fontSize: 14,
    color: theme.colors.text.secondary,
  },
  actionsSection: {
    marginTop: 8,
  },
  actionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: theme.colors.white,
    borderRadius: 12,
    padding: 16,
    marginBottom: 8,
  },
  actionText: {
    flex: 1,
    fontSize: 16,
    color: theme.colors.text.primary,
    marginLeft: 12,
  },
  logoutButton: {
    marginTop: 16,
  },
  logoutText: {
    color: theme.colors.accent,
  },
});