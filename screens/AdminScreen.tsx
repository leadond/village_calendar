import React, { useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  FlatList,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useMutation, useQuery } from 'convex/react';

import { api } from '../convex/_generated/api';
import { theme } from '../lib/theme';

export default function AdminScreen({ navigation }: { navigation: any }) {
  const status = useQuery(api.adminAuth.getAdminStatus, {});
  const stats = useQuery(api.admin.getStats, {});
  const admins = useQuery(api.adminAuth.listAdmins, {});
  const users = useQuery(api.adminAuth.getAllUsers, {});

  const addAdmin = useMutation(api.adminAuth.addAdmin);
  const removeAdmin = useMutation(api.adminAuth.removeAdmin);

  const [userId, setUserId] = useState('');
  const canManageAdmins = status?.role === 'owner';

  const userLookup = useMemo(() => {
    const map = new Map<string, { name: string; isAdmin: boolean }>();
    (users ?? []).forEach((u: any) => map.set(u.userId, { name: u.name, isAdmin: u.isAdmin }));
    return map;
  }, [users]);

  const [testUserName, setTestUserName] = useState('');
  const [testUserEmail, setTestUserEmail] = useState('');
  const [testUserRole, setTestUserRole] = useState<'parent' | 'helper'>('helper');
  const [isCreating, setIsCreating] = useState(false);
  const createTestUser = useMutation(api.admin.createTestUser);

  const handleCreateTestUser = async () => {
    if (!testUserName.trim()) return;
    setIsCreating(true);
    try {
      await createTestUser({
        name: testUserName,
        email: testUserEmail || undefined,
        role: testUserRole,
      });
      setTestUserName('');
      setTestUserEmail('');
      Alert.alert('Success', 'User created! They are confirmed and ready.');
    } catch (error: any) {
      Alert.alert('Error', error.message || 'Failed to create user');
    } finally {
      setIsCreating(false);
    }
  };

  const handleAddAdmin = async () => {
    const trimmed = userId.trim();
    if (!trimmed) return;

    try {
      await addAdmin({ userId: trimmed, role: 'admin' });
      setUserId('');
      Alert.alert('Added', 'Admin added.');
    } catch (e: any) {
      Alert.alert('Error', e?.message ?? 'Failed to add admin');
    }
  };

  const handleRemoveAdmin = async (adminId: any, role: 'owner' | 'admin') => {
    if (!canManageAdmins) return;

    Alert.alert(
      'Remove admin?',
      role === 'owner'
        ? 'Removing an owner is restricted (must not be the last owner).'
        : 'This user will lose admin access.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Remove',
          style: 'destructive',
          onPress: async () => {
            try {
              await removeAdmin({ adminId });
            } catch (e: any) {
              Alert.alert('Error', e?.message ?? 'Failed to remove admin');
            }
          },
        },
      ]
    );
  };

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <View style={styles.header}>
        <TouchableOpacity
          style={styles.backBtn}
          onPress={() => navigation.goBack()}
          accessibilityLabel="Go back to previous screen"
          accessibilityHint="Navigate back to the previous screen"
          accessibilityRole="button"
        >
          <Ionicons name="chevron-back" size={22} color={theme.colors.text.primary} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Admin</Text>
        <View style={{ width: 40 }} />
      </View>

      <FlatList
        data={[{ key: 'content' }]}
        keyExtractor={(i: any) => `admin-${i.key}`}
        getItemLayout={(data, index) => ({
          length: 800,
          offset: 800 * index,
          index,
        })}
        renderItem={() => (
          <View style={styles.content}>
            <Text style={styles.sectionTitle}>Overview</Text>

            {!stats ? (
              <View style={styles.loadingRow}>
                <ActivityIndicator color={theme.colors.primary} />
              </View>
            ) : (
              <View style={styles.statsGrid}>
                <Stat label="Villages" value={stats.totalVillages} />
                <Stat label="Profiles" value={stats.totalProfiles} />
                <Stat label="Requests" value={stats.totalHelpRequests} />
                <Stat label="Open" value={stats.openRequests} />
                <Stat label="Claimed" value={stats.claimedRequests} />
                <Stat label="Parents" value={stats.parentCount} />
                <Stat label="Helpers" value={stats.helperCount} />
              </View>
            )}

            <Text style={[styles.sectionTitle, { marginTop: 24 }]}>Admins</Text>

            {admins === undefined ? (
              <View style={styles.loadingRow}>
                <ActivityIndicator color={theme.colors.primary} />
              </View>
            ) : admins?.length ? (
              <View style={styles.card}>
                {admins.map((a: any) => {
                  const user = userLookup.get(a.userId);
                  return (
                    <View key={`admin-${a.id}`} style={styles.row}>
                      <View style={{ flex: 1 }}>
                        <Text style={styles.rowTitle} numberOfLines={1}>
                          {user?.name ?? a.name ?? a.userId}
                        </Text>
                        <Text style={styles.rowSubtitle} numberOfLines={1}>
                          {a.role} • {a.userId}
                        </Text>
                      </View>

                      {canManageAdmins && (
                        <TouchableOpacity
                          style={styles.iconBtn}
                          onPress={() => handleRemoveAdmin(a.id, a.role)}
                          accessibilityLabel="Remove admin"
                          accessibilityHint="Remove this admin user"
                          accessibilityRole="button"
                        >
                          <Ionicons name="trash-outline" size={18} color={theme.colors.accent} />
                        </TouchableOpacity>
                      )}
                    </View>
                  );
                })}

                {canManageAdmins && (
                  <View style={styles.addAdminRow}>
                    <TextInput
                      style={styles.input}
                      value={userId}
                      onChangeText={setUserId}
                      placeholder="User ID (identity.subject)"
                      placeholderTextColor={theme.colors.gray.medium}
                      autoCapitalize="none"
                      accessibilityLabel="User ID input"
                      accessibilityHint="Enter the user ID to add as admin"
                    />
                    <TouchableOpacity
                      style={[styles.addBtn, !userId.trim() && styles.addBtnDisabled]}
                      disabled={!userId.trim()}
                      onPress={handleAddAdmin}
                      accessibilityLabel="Add admin"
                      accessibilityHint="Add the specified user as an admin"
                      accessibilityRole="button"
                    >
                      <Text style={styles.addBtnText}>Add</Text>
                    </TouchableOpacity>
                  </View>
                )}

                {!canManageAdmins && (
                  <Text style={styles.noteText}>Only the owner can add/remove admins.</Text>
                )}
              </View>
            ) : (
              <Text style={styles.noteText}>No admins found.</Text>
            )}

            <Text style={[styles.sectionTitle, { marginTop: 24 }]}>Create Confirmed User</Text>
            <View style={styles.card}>
              <TextInput
                style={[styles.input, { marginBottom: 12 }]}
                placeholder="Full Name"
                value={testUserName}
                onChangeText={setTestUserName}
              />
              <TextInput
                style={[styles.input, { marginBottom: 12 }]}
                placeholder="Email (optional, for auto-link)"
                value={testUserEmail}
                onChangeText={setTestUserEmail}
                autoCapitalize="none"
              />
              <View style={styles.roleSelector}>
                <TouchableOpacity
                  style={[styles.roleOption, testUserRole === 'parent' && styles.roleOptionSelected]}
                  onPress={() => setTestUserRole('parent')}
                >
                  <Text style={[styles.roleOptionText, testUserRole === 'parent' && styles.roleOptionTextSelected]}>Parent</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[styles.roleOption, testUserRole === 'helper' && styles.roleOptionSelected]}
                  onPress={() => setTestUserRole('helper')}
                >
                  <Text style={[styles.roleOptionText, testUserRole === 'helper' && styles.roleOptionTextSelected]}>Helper</Text>
                </TouchableOpacity>
              </View>
              <TouchableOpacity
                style={[styles.createBtn, (!testUserName.trim()) && styles.disabledBtn]}
                disabled={!testUserName.trim()}
                onPress={handleCreateTestUser}
              >
                {isCreating ? <ActivityIndicator color="#fff" /> : <Text style={styles.createBtnText}>Create User</Text>}
              </TouchableOpacity>
            </View>

            <Text style={[styles.sectionTitle, { marginTop: 24 }]}>Users</Text>

            {users === undefined ? (
              <View style={styles.loadingRow}>
                <ActivityIndicator color={theme.colors.primary} />
              </View>
            ) : (
              <View style={styles.card}>
                {(users ?? []).slice(0, 50).map((u: any) => (
                  <View key={`user-${u.userId}`} style={styles.row}>
                    <View style={{ flex: 1 }}>
                      <Text style={styles.rowTitle} numberOfLines={1}>
                        {u.name}
                      </Text>
                      <Text style={styles.rowSubtitle} numberOfLines={1}>
                        {u.role} • {u.villageName}
                      </Text>
                    </View>
                    {u.isAdmin && (
                      <View style={styles.badge}>
                        <Text style={styles.badgeText}>Admin</Text>
                      </View>
                    )}
                  </View>
                ))}
                <Text style={styles.noteText}>
                  Showing first 50 users. For full exports, use the Convex dashboard.
                </Text>
              </View>
            )}
          </View>
        )}
        removeClippedSubviews={true}
        maxToRenderPerBatch={3}
        windowSize={5}
        initialNumToRender={1}
        legacyImplementation={false}
      />
    </SafeAreaView>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <View style={styles.statCard}>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
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
  headerTitle: {
    flex: 1,
    textAlign: 'center',
    fontSize: 18,
    fontWeight: '700',
    color: theme.colors.text.primary,
  },
  content: {
    padding: 16,
    paddingBottom: 32,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: theme.colors.text.primary,
    marginBottom: 12,
  },
  loadingRow: {
    paddingVertical: 24,
  },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  statCard: {
    width: '48%',
    backgroundColor: theme.colors.white,
    borderRadius: 14,
    padding: 14,
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
  },
  statValue: {
    fontSize: 22,
    fontWeight: '800',
    color: theme.colors.primary,
  },
  statLabel: {
    marginTop: 2,
    fontSize: 13,
    color: theme.colors.text.secondary,
  },
  card: {
    backgroundColor: theme.colors.white,
    borderRadius: 16,
    padding: 12,
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: theme.colors.gray.light,
    gap: 12,
  },
  rowTitle: {
    fontSize: 15,
    fontWeight: '700',
    color: theme.colors.text.primary,
  },
  rowSubtitle: {
    marginTop: 2,
    fontSize: 12,
    color: theme.colors.text.secondary,
  },
  iconBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: theme.colors.background,
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
  },
  addAdminRow: {
    flexDirection: 'row',
    gap: 10,
    paddingTop: 12,
  },
  input: {
    flex: 1,
    height: 44,
    borderRadius: 12,
    paddingHorizontal: 12,
    backgroundColor: theme.colors.background,
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
    color: theme.colors.text.primary,
  },
  addBtn: {
    height: 44,
    paddingHorizontal: 16,
    borderRadius: 12,
    backgroundColor: theme.colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  addBtnDisabled: {
    opacity: 0.5,
  },
  addBtnText: {
    color: theme.colors.white,
    fontWeight: '700',
  },
  badge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 999,
    backgroundColor: theme.colors.primary + '15',
  },
  badgeText: {
    fontSize: 12,
    fontWeight: '700',
    color: theme.colors.primary,
  },
  noteText: {
    marginTop: 10,
    fontSize: 12,
    color: theme.colors.text.secondary,
  },
  roleSelector: {
    flexDirection: 'row',
    marginBottom: 12,
    gap: 8,
  },
  roleOption: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
    alignItems: 'center',
  },
  roleOptionSelected: {
    backgroundColor: theme.colors.primary,
    borderColor: theme.colors.primary,
  },
  roleOptionText: {
    color: theme.colors.text.secondary,
    fontWeight: '600',
  },
  roleOptionTextSelected: {
    color: theme.colors.white,
  },
  createBtn: {
    backgroundColor: theme.colors.primary,
    paddingVertical: 12,
    borderRadius: 12,
    alignItems: 'center',
  },
  createBtnText: {
    color: theme.colors.white,
    fontWeight: '700',
    fontSize: 16,
  },
  disabledBtn: {
    opacity: 0.5,
  },
});