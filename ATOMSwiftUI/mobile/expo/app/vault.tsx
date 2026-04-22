import { CreditCard, FileLock2, IdCard, ShieldCheck, Sparkles, Store, TimerReset } from "lucide-react-native";
import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Animated, Pressable, Text, TextInput, View } from "react-native";

import { EnvironmentShell } from "../components/EnvironmentShell";
import { ActionChip, SectionCard, SurfaceScroll, buildRailActions, styles as ui } from "../components/LilithPrimitives";
import { browserTheme } from "../constants/colors";
import { apiRequest } from "../lib/api";
import { useCommandContext } from "../providers/CommandContextProvider";
import { useSession } from "../providers/SessionProvider";

type VaultProfile = {
  id: string;
  profile_name: string;
  profile_type: string;
  is_default: boolean;
  requires_unlock: boolean;
  fields?: Record<string, string>;
};

type VaultDocument = {
  id: string;
  title: string;
  doc_type: string;
  file_url: string;
  updated_at: string;
};

type VaultLog = {
  id: string;
  action: string;
  resource_type: string;
  approved: boolean;
  reason: string;
  created_at: string;
};

function maskValue(value?: string) {
  if (!value) return "••••••";
  const trimmed = String(value);
  if (trimmed.length < 5) return "••••";
  return `${trimmed.slice(0, 2)}••••${trimmed.slice(-2)}`;
}

export default function VaultScreen() {
  const { apiBase, token } = useSession();
  const { vaultLocked, vaultLockUntil, lockVault, unlockVault } = useCommandContext();
  const [profiles, setProfiles] = useState<VaultProfile[]>([]);
  const [docs, setDocs] = useState<VaultDocument[]>([]);
  const [logs, setLogs] = useState<VaultLog[]>([]);
  const [unlockToken, setUnlockToken] = useState("");
  const [formFields, setFormFields] = useState("legal_name,email,phone,address,tax_id");
  const [detectResult, setDetectResult] = useState<any | null>(null);
  const [selectedFields, setSelectedFields] = useState<string[]>([]);
  const [status, setStatus] = useState("Vault locked until approval.");
  const [remaining, setRemaining] = useState(0);
  const unlockAnim = useRef(new Animated.Value(0)).current;
  const autofillAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (vaultLocked || vaultLockUntil <= 0) {
      setRemaining(0);
      return;
    }
    const timer = setInterval(() => {
      const next = Math.max(0, vaultLockUntil - Date.now());
      setRemaining(next);
    }, 500);
    return () => clearInterval(timer);
  }, [vaultLocked, vaultLockUntil]);

  const remainingLabel = useMemo(() => {
    if (vaultLocked) return "Locked";
    const mins = Math.floor(remaining / 60000);
    const secs = Math.floor((remaining % 60000) / 1000);
    return `Unlocked ${mins}:${secs.toString().padStart(2, "0")}`;
  }, [vaultLocked, remaining]);

  const load = useCallback(async () => {
    try {
      const [profilesRes, docsRes, logsRes] = await Promise.all([
        apiRequest<{ items: VaultProfile[] }>(
          apiBase,
          token,
          `/api/v1/storage/vault/profiles?include_fields=${vaultLocked ? "false" : "true"}${!vaultLocked ? `&unlock_token=${encodeURIComponent(unlockToken || "session_unlock")}` : ""}`
        ),
        apiRequest<{ items: VaultDocument[] }>(apiBase, token, "/api/v1/storage/vault/documents"),
        apiRequest<{ items: VaultLog[] }>(apiBase, token, "/api/v1/storage/vault/access-logs"),
      ]);
      setProfiles(profilesRes.items || []);
      setDocs(docsRes.items || []);
      setLogs(logsRes.items || []);
      setStatus(`Vault ready. ${profilesRes.items.length} profiles loaded.`);
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token, vaultLocked, unlockToken]);

  useEffect(() => {
    load();
  }, [load]);

  const seedProfile = useCallback(async () => {
    try {
      await apiRequest(apiBase, token, "/api/v1/storage/vault/profiles", "POST", {
        profile_name: "Primary Identity",
        profile_type: "personal",
        is_default: true,
        fields: {
          legal_name: "Alex Taylor",
          email: "alex@example.com",
          phone: "+1-202-555-0114",
          address: "100 Main St, Austin, TX",
          tax_id: "123-45-6789",
          business_name: "Orbit Studio LLC",
          payout_preference: "USDC",
        },
      });
      setStatus("Seeded default vault profile.");
      await load();
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token, load]);

  const detectAutofill = useCallback(async () => {
    try {
      const out = await apiRequest<any>(apiBase, token, "/api/v1/storage/autofill/detect", "POST", {
        form_name: "Business Filing Form",
        target_type: "business_filing",
        fields: formFields
          .split(",")
          .map((x) => x.trim())
          .filter(Boolean),
      });
      setDetectResult(out);
      setSelectedFields((out.matches || []).map((x: any) => x.field));
      setStatus("Autofill preview generated.");
      Animated.sequence([
        Animated.timing(autofillAnim, { toValue: 1, duration: 200, useNativeDriver: true }),
        Animated.timing(autofillAnim, { toValue: 0, duration: 220, useNativeDriver: true }),
      ]).start();
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token, formFields, autofillAnim]);

  const applyAutofill = useCallback(
    async (mode: "fill_all" | "review_first" | "fill_selected") => {
      try {
        if (!profiles[0]) {
          setStatus("Create or load a vault profile first.");
          return;
        }
        const out = await apiRequest<any>(apiBase, token, "/api/v1/storage/autofill/apply", "POST", {
          profile_id: profiles[0].id,
          fields: selectedFields,
          mode,
          approved: true,
          unlock_token: !vaultLocked ? unlockToken || "session_unlock" : undefined,
        });
        setDetectResult(out);
        setStatus("Autofill prepared. Manual submit only.");
        Animated.sequence([
          Animated.timing(autofillAnim, { toValue: 1, duration: 200, useNativeDriver: true }),
          Animated.timing(autofillAnim, { toValue: 0, duration: 220, useNativeDriver: true }),
        ]).start();
        await load();
      } catch (error) {
        setStatus(String(error));
      }
    },
    [apiBase, token, profiles, selectedFields, unlockToken, load, vaultLocked, autofillAnim]
  );

  const identityProfile = profiles[0];
  const fields = identityProfile?.fields || {};

  return (
    <EnvironmentShell
      screenKey="vault"
      title="Vault"
      subtitle="Calm high-security memory for identity, payments, business, and sensitive documents."
      leftActions={buildRailActions("left", "vault")}
      rightActions={buildRailActions("right", "vault")}
      bottomActions={buildRailActions("bottom", "vault")}
    >
      <SurfaceScroll>
        <SectionCard title="Vault Lock" subtitle={status}>
          <Animated.View
            style={{
              borderRadius: 14,
              borderWidth: 1,
              borderColor: vaultLocked ? "rgba(238,90,90,0.35)" : "rgba(47,210,132,0.35)",
              backgroundColor: vaultLocked ? "rgba(238,90,90,0.08)" : "rgba(47,210,132,0.08)",
              padding: 12,
              gap: 8,
              transform: [{ scale: unlockAnim.interpolate({ inputRange: [0, 1], outputRange: [1, 1.02] }) }],
            }}
          >
            <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between" }}>
              <View style={{ flexDirection: "row", alignItems: "center", gap: 7 }}>
                <ShieldCheck size={15} color={vaultLocked ? browserTheme.critical : browserTheme.success} />
                <Text style={{ color: browserTheme.text, fontWeight: "800" }}>{remainingLabel}</Text>
              </View>
              <View style={{ flexDirection: "row", alignItems: "center", gap: 5 }}>
                <TimerReset size={13} color={browserTheme.textMuted} />
                <Text style={{ color: browserTheme.textMuted, fontSize: 11 }}>Auto-lock active</Text>
              </View>
            </View>
            <TextInput
              value={unlockToken}
              onChangeText={setUnlockToken}
              placeholder="Unlock token (biometric/passkey hook)"
              placeholderTextColor={browserTheme.textMuted}
              secureTextEntry
              style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
            />
            <View
              style={{
                borderRadius: 10,
                borderWidth: 1,
                borderColor: browserTheme.border,
                backgroundColor: "rgba(17,29,48,0.72)",
                padding: 9,
              }}
            >
              <Text style={{ color: browserTheme.textMuted, fontSize: 11 }}>
                Your data stays in Lilith Vault and sensitive fields are never auto-submitted.
              </Text>
            </View>
            <View style={ui.rowWrap}>
              <ActionChip label="Load" onPress={load} />
              <ActionChip label="Seed Profile" onPress={seedProfile} />
              <ActionChip
                label={vaultLocked ? "Unlock (5m)" : "Lock Now"}
                onPress={() => {
                  if (vaultLocked) {
                    if ((unlockToken || "").trim().length < 4) {
                      setStatus("Enter unlock token.");
                      return;
                    }
                    unlockVault(5 * 60 * 1000);
                    setStatus("Vault unlocked for 5 minutes.");
                    Animated.sequence([
                      Animated.timing(unlockAnim, { toValue: 1, duration: 220, useNativeDriver: true }),
                      Animated.timing(unlockAnim, { toValue: 0, duration: 240, useNativeDriver: true }),
                    ]).start();
                  } else {
                    lockVault();
                    setStatus("Vault locked.");
                  }
                }}
              />
            </View>
          </Animated.View>
        </SectionCard>

        <SectionCard title="Secure Sections" subtitle="Structured fields with masked defaults">
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 10 }}>
            {[
              { label: "Identity", icon: IdCard, values: [fields.legal_name, fields.email, fields.phone] },
              { label: "Payments", icon: CreditCard, values: [fields.tax_id, fields.payout_preference] },
              { label: "Business", icon: Store, values: [fields.business_name, fields.address] },
              { label: "Documents", icon: FileLock2, values: [docs[0]?.title, docs[1]?.title] },
            ].map((section) => (
              <View
                key={section.label}
                style={{
                  width: "47%",
                  borderRadius: 14,
                  borderWidth: 1,
                  borderColor: browserTheme.border,
                  backgroundColor: browserTheme.panelElevated,
                  padding: 10,
                  gap: 6,
                }}
              >
                <View style={{ flexDirection: "row", alignItems: "center", gap: 6 }}>
                  <section.icon size={14} color={browserTheme.action} />
                  <Text style={{ color: browserTheme.text, fontWeight: "800", fontSize: 13 }}>{section.label}</Text>
                </View>
                {section.values.filter(Boolean).slice(0, 2).map((v, i) => (
                  <Text key={`${section.label}-${i}`} style={{ color: browserTheme.textMuted, fontSize: 11 }}>
                    {vaultLocked ? maskValue(String(v)) : String(v)}
                  </Text>
                ))}
              </View>
            ))}
          </View>
        </SectionCard>

        <SectionCard title="Autofill Preview" subtitle="Review before fill. Sensitive fields remain controlled.">
          <Animated.View style={{ opacity: autofillAnim.interpolate({ inputRange: [0, 1], outputRange: [1, 0.84] }) }}>
            <TextInput
              value={formFields}
              onChangeText={setFormFields}
              placeholder="Comma-separated form fields"
              placeholderTextColor={browserTheme.textMuted}
              style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
            />
          </Animated.View>
          <View style={ui.rowWrap}>
            <ActionChip label="Preview" onPress={detectAutofill} />
            <ActionChip label="Fill All" onPress={() => applyAutofill("fill_all")} />
            <ActionChip label="Review First" onPress={() => applyAutofill("review_first")} />
            <ActionChip label="Fill Selected" onPress={() => applyAutofill("fill_selected")} />
          </View>
          {detectResult?.matches?.length ? (
            <View style={ui.rowWrap}>
              {detectResult.matches.map((m: any) => {
                const selected = selectedFields.includes(m.field);
                return (
                  <Pressable
                    key={m.field}
                    onPress={() =>
                      setSelectedFields((prev) =>
                        prev.includes(m.field) ? prev.filter((x) => x !== m.field) : [...prev, m.field]
                      )
                    }
                    style={{
                      borderRadius: 999,
                      borderWidth: 1,
                      borderColor: selected ? browserTheme.action : browserTheme.border,
                      backgroundColor: selected ? "rgba(79,163,255,0.2)" : browserTheme.panelElevated,
                      paddingHorizontal: 10,
                      paddingVertical: 8,
                    }}
                  >
                    <Text style={{ color: browserTheme.textSoft, fontSize: 12, fontWeight: "700" }}>
                      {m.field} {m.sensitive ? "• secure" : ""}
                    </Text>
                  </Pressable>
                );
              })}
            </View>
          ) : (
            <View style={{ borderRadius: 12, padding: 12, backgroundColor: browserTheme.panelElevated, alignItems: "center", gap: 5 }}>
              <Sparkles size={14} color={browserTheme.textMuted} />
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>Preview a form to see fillable secure fields.</Text>
            </View>
          )}
        </SectionCard>

        <SectionCard title="Vault Activity" subtitle={`${logs.length} recent access events`}>
          {logs.slice(0, 6).map((log) => (
            <View key={log.id} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>
                {log.action} • {log.approved ? "approved" : "blocked"}
              </Text>
              <Text style={ui.bodyText}>{log.reason || log.resource_type}</Text>
            </View>
          ))}
        </SectionCard>

        {!profiles.length ? (
          <SectionCard title="Get Started" subtitle="Set up secure identity once">
            <View style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, backgroundColor: browserTheme.panelElevated, padding: 12, gap: 8 }}>
              <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>
                Add your primary profile to unlock one-tap secure autofill previews across forms and checkouts.
              </Text>
              <View style={ui.rowWrap}>
                <ActionChip label="Create Secure Profile" onPress={seedProfile} />
                <ActionChip label="Preview Autofill" onPress={detectAutofill} />
              </View>
            </View>
          </SectionCard>
        ) : null}

        {vaultLocked ? (
          <View
            style={{
              position: "absolute",
              left: 12,
              right: 12,
              top: 12,
              bottom: 12,
              borderRadius: 18,
              backgroundColor: "rgba(6,12,22,0.74)",
              borderWidth: 1,
              borderColor: browserTheme.border,
              alignItems: "center",
              justifyContent: "center",
              padding: 16,
            }}
          >
            <FileLock2 size={18} color={browserTheme.textMuted} />
            <Text style={{ color: browserTheme.text, fontSize: 16, fontWeight: "800", marginTop: 8 }}>Vault Locked</Text>
            <Text style={{ color: browserTheme.textMuted, fontSize: 12, marginTop: 6, textAlign: "center" }}>
              Sensitive data is protected. Unlock to reveal secure fields and sensitive autofill actions.
            </Text>
          </View>
        ) : null}
      </SurfaceScroll>
    </EnvironmentShell>
  );
}
