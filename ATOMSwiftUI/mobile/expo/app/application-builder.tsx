import React, { useEffect, useMemo, useState } from "react";
import { Pressable, ScrollView, Text, TextInput, View } from "react-native";

import { EnvironmentShell } from "../components/EnvironmentShell";
import { ActionChip, SectionCard, SurfaceScroll, buildRailActions, styles as ui } from "../components/LilithPrimitives";
import { browserTheme } from "../constants/colors";
import { apiRequest } from "../lib/api";
import { useCommandContext } from "../providers/CommandContextProvider";
import { useSession } from "../providers/SessionProvider";

type AppField = {
  key: string;
  label: string;
  field_type: string;
  required: boolean;
  position: number;
  source_type: "vault" | "upload" | "manual";
  source_key: string;
};

type AppRule = {
  name: string;
  condition: { field: string; equals: string };
  effect: { require: string[] };
  active: boolean;
};

type AppTemplate = {
  id: string;
  name: string;
  description: string;
  delivery_mode: string;
  pricing_model: string;
  per_request_fee: number;
  currency: string;
  fields: AppField[];
  rules: AppRule[];
  market?: {
    is_public: boolean;
    category: string;
    tags: string[];
    usage_count: number;
  };
};

type AppProfile = {
  id: string;
  profile_name: string;
  fields: Record<string, string>;
  is_default: boolean;
};

const fieldTypes = ["text", "email", "phone", "number", "select", "date"];
const sourceTypes: Array<AppField["source_type"]> = ["vault", "upload", "manual"];
const deliveryModes = ["direct", "link", "api"];
const pricingModels = ["subscription", "per_request", "enterprise"];
const defaultCategories = ["All", "General", "HR", "Finance", "Legal", "Onboarding", "Operations"];

export default function ApplicationBuilderScreen() {
  const { apiBase, token } = useSession();
  const { setActiveSelectedContent } = useCommandContext();

  const [templates, setTemplates] = useState<AppTemplate[]>([]);
  const [selectedTemplateId, setSelectedTemplateId] = useState("");
  const [status, setStatus] = useState("Build once. Send instantly. Reuse forever.");
  const [vaultProfiles, setVaultProfiles] = useState<Array<{ id: string; profile_name: string }>>([]);
  const [reusableProfiles, setReusableProfiles] = useState<AppProfile[]>([]);
  const [preview, setPreview] = useState<any>(null);
  const [analytics, setAnalytics] = useState<any>(null);
  const [targetUserId, setTargetUserId] = useState("");
  const [recentUsers, setRecentUsers] = useState<Array<{ user_id: string; username: string }>>([]);
  const [previewProfileId, setPreviewProfileId] = useState("");
  const [reusableProfileId, setReusableProfileId] = useState("");
  const [draggingFieldIndex, setDraggingFieldIndex] = useState<number | null>(null);
  const [marketTemplates, setMarketTemplates] = useState<AppTemplate[]>([]);
  const [marketCategories, setMarketCategories] = useState<Array<{ category: string; count: number }>>([]);
  const [marketCategory, setMarketCategory] = useState("All");
  const [marketQuery, setMarketQuery] = useState("");
  const [fieldSuggestions, setFieldSuggestions] = useState<AppField[]>([]);
  const [shareToken, setShareToken] = useState("");

  const [createInput, setCreateInput] = useState({
    name: "New Business Request",
    description: "Tell us what you need and Lilith can complete instantly.",
    delivery_mode: "direct",
    pricing_model: "subscription",
    per_request_fee: "2.00",
    currency: "USD",
    category: "General",
  });

  const [newField, setNewField] = useState<AppField>({
    key: "full_name",
    label: "Full Name",
    field_type: "text",
    required: true,
    position: 0,
    source_type: "vault",
    source_key: "full_name",
  });

  const [newRule, setNewRule] = useState<AppRule>({
    name: "Require Tax ID for Business Applicants",
    condition: { field: "applicant_type", equals: "business" },
    effect: { require: ["tax_id"] },
    active: true,
  });

  const [profileDraftName, setProfileDraftName] = useState("Default Application Profile");

  const selected = useMemo(() => templates.find((t) => t.id === selectedTemplateId) || null, [templates, selectedTemplateId]);

  const loadTemplates = async () => {
    try {
      const res = await apiRequest<{ items: AppTemplate[] }>(apiBase, token, "/api/v1/applications/templates");
      setTemplates(res.items || []);
      if (!selectedTemplateId && res.items?.[0]?.id) setSelectedTemplateId(res.items[0].id);
    } catch (error) {
      setStatus(String(error));
    }
  };

  const loadVaultProfiles = async () => {
    try {
      const res = await apiRequest<{ profiles: Array<{ id: string; profile_name: string }> }>(apiBase, token, "/api/v1/storage/vault/profiles");
      setVaultProfiles(res.profiles || []);
      if (!previewProfileId && res.profiles?.[0]?.id) setPreviewProfileId(res.profiles[0].id);
    } catch {
      // Non-blocking.
    }
  };

  const loadReusableProfiles = async () => {
    try {
      const res = await apiRequest<{ items: AppProfile[] }>(apiBase, token, "/api/v1/applications/profiles");
      setReusableProfiles(res.items || []);
      if (!reusableProfileId && res.items?.[0]?.id) setReusableProfileId(res.items[0].id);
    } catch {
      // Non-blocking.
    }
  };

  const loadRecentUsers = async () => {
    try {
      const res = await apiRequest<{ items: Array<{ user_id: string; username: string }> }>(apiBase, token, "/api/v1/applications/recent-users");
      setRecentUsers(res.items || []);
    } catch {
      // Non-blocking.
    }
  };

  const loadMarketplace = async () => {
    try {
      const params = new URLSearchParams();
      if (marketCategory !== "All") params.append("category", marketCategory);
      if (marketQuery.trim()) params.append("query", marketQuery.trim());
      const [templatesRes, categoriesRes] = await Promise.all([
        apiRequest<{ items: AppTemplate[] }>(apiBase, token, `/api/v1/applications/marketplace/templates?${params.toString()}`),
        apiRequest<{ items: Array<{ category: string; count: number }> }>(apiBase, token, "/api/v1/applications/marketplace/categories"),
      ]);
      setMarketTemplates(templatesRes.items || []);
      setMarketCategories(categoriesRes.items || []);
    } catch {
      // Non-blocking.
    }
  };

  useEffect(() => {
    loadTemplates();
    loadVaultProfiles();
    loadReusableProfiles();
    loadRecentUsers();
  }, []);

  useEffect(() => {
    loadMarketplace();
  }, [marketCategory, marketQuery]);

  const createTemplate = async () => {
    try {
      const created = await apiRequest<AppTemplate>(apiBase, token, "/api/v1/applications/templates", "POST", {
        ...createInput,
        per_request_fee: Number(createInput.per_request_fee || "0"),
        metadata: {
          category: createInput.category,
          is_public: false,
        },
      });
      setStatus(`Template created: ${created.name}`);
      setSelectedTemplateId(created.id);
      await loadTemplates();
    } catch (error) {
      setStatus(String(error));
    }
  };

  const updateMarketplaceSettings = async (isPublic?: boolean) => {
    if (!selected) return;
    try {
      const updated = await apiRequest<AppTemplate>(apiBase, token, `/api/v1/applications/templates/${selected.id}/marketplace`, "POST", {
        is_public: isPublic ?? !selected.market?.is_public,
        category: selected.market?.category || createInput.category,
        tags: selected.market?.tags || [],
      });
      setTemplates((prev) => prev.map((t) => (t.id === updated.id ? updated : t)));
      setStatus(updated.market?.is_public ? "Template published to marketplace." : "Template moved to private mode.");
      await loadMarketplace();
    } catch (error) {
      setStatus(String(error));
    }
  };

  const cloneFromMarketplace = async (templateId: string) => {
    try {
      const cloned = await apiRequest<AppTemplate>(apiBase, token, `/api/v1/applications/templates/${templateId}/clone`, "POST");
      setSelectedTemplateId(cloned.id);
      setStatus(`Cloned template: ${cloned.name}`);
      await loadTemplates();
    } catch (error) {
      setStatus(String(error));
    }
  };

  const persistFields = async (fields: AppField[]) => {
    if (!selected) return;
    const normalized = fields.map((f, idx) => ({ ...f, position: idx }));
    try {
      const updated = await apiRequest<AppTemplate>(
        apiBase,
        token,
        `/api/v1/applications/templates/${selected.id}/fields`,
        "POST",
        { fields: normalized }
      );
      setTemplates((prev) => prev.map((t) => (t.id === updated.id ? updated : t)));
      setStatus("Fields saved.");
    } catch (error) {
      setStatus(String(error));
    }
  };

  const persistRules = async (rules: AppRule[]) => {
    if (!selected) return;
    try {
      const updated = await apiRequest<AppTemplate>(apiBase, token, `/api/v1/applications/templates/${selected.id}/rules`, "POST", { rules });
      setTemplates((prev) => prev.map((t) => (t.id === updated.id ? updated : t)));
      setStatus("Rules saved.");
    } catch (error) {
      setStatus(String(error));
    }
  };

  const fetchFieldSuggestions = async () => {
    if (!selected) return;
    try {
      const category = selected.market?.category || "General";
      const res = await apiRequest<{ items: AppField[] }>(
        apiBase,
        token,
        `/api/v1/applications/templates/${selected.id}/suggest-fields?category=${encodeURIComponent(category)}`
      );
      setFieldSuggestions(res.items || []);
      setStatus("Field suggestions loaded.");
    } catch (error) {
      setStatus(String(error));
    }
  };

  const applySuggestion = async (field: AppField) => {
    if (!selected) return;
    const next = [
      ...selected.fields,
      {
        ...field,
        key: field.key.trim().toLowerCase().replace(/\s+/g, "_"),
        label: field.label.trim(),
        position: selected.fields.length,
      },
    ];
    await persistFields(next);
  };

  const addField = async () => {
    if (!selected) return;
    const next = [
      ...selected.fields,
      {
        ...newField,
        key: newField.key.trim().toLowerCase().replace(/\s+/g, "_"),
        label: newField.label.trim(),
        position: selected.fields.length,
      },
    ];
    await persistFields(next);
  };

  const moveFieldToIndex = async (from: number, to: number) => {
    if (!selected || from === to || from < 0 || to < 0 || from >= selected.fields.length || to >= selected.fields.length) return;
    const next = [...selected.fields];
    const [picked] = next.splice(from, 1);
    next.splice(to, 0, picked);
    await persistFields(next);
  };

  const addRule = async () => {
    if (!selected) return;
    await persistRules([...selected.rules, newRule]);
  };

  const runPreview = async () => {
    if (!selected) return;
    try {
      const data = await apiRequest<any>(apiBase, token, `/api/v1/applications/templates/${selected.id}/preview`, "POST", {
        vault_profile_id: previewProfileId || undefined,
        reusable_profile_id: reusableProfileId || undefined,
        manual_data: {},
      });
      setPreview(data);
      setActiveSelectedContent(JSON.stringify(data, null, 2));
      setStatus(data.can_auto_complete ? "Preview complete. Ready to auto-complete." : "Preview complete. Missing required fields.");
    } catch (error) {
      setStatus(String(error));
    }
  };

  const loadAnalytics = async () => {
    if (!selected) return;
    try {
      const data = await apiRequest<any>(apiBase, token, `/api/v1/applications/templates/${selected.id}/analytics`);
      setAnalytics(data);
      setStatus("Analytics loaded.");
    } catch (error) {
      setStatus(String(error));
    }
  };

  const sendRequest = async (channel: string) => {
    if (!selected) return;
    try {
      const sent = await apiRequest<any>(apiBase, token, `/api/v1/applications/templates/${selected.id}/send`, "POST", {
        target_user_id: targetUserId || undefined,
        channel,
        prefill: preview?.fields ? Object.fromEntries(preview.fields.filter((f: any) => f.preview_value).map((f: any) => [f.key, f.preview_value])) : {},
        metadata: { source: "application_builder_canvas" },
      });
      setShareToken(sent.public_link_token || "");
      setStatus(`Request sent (${sent.channel}). Link token ready.`);
      setActiveSelectedContent(JSON.stringify(sent, null, 2));
      await loadRecentUsers();
    } catch (error) {
      setStatus(String(error));
    }
  };

  const quickSend = async () => {
    if (!selected) return;
    try {
      const sent = await apiRequest<any>(
        apiBase,
        token,
        `/api/v1/applications/templates/${selected.id}/quick-send`,
        "POST",
        { target_user_id: targetUserId || undefined }
      );
      setShareToken(sent.public_link_token || "");
      setStatus(`Quick send complete (${sent.channel}).`);
      setActiveSelectedContent(JSON.stringify(sent, null, 2));
      await loadRecentUsers();
    } catch (error) {
      setStatus(String(error));
    }
  };

  const saveReusableProfile = async () => {
    if (!preview?.fields) return;
    try {
      const fields = Object.fromEntries(
        preview.fields.filter((f: any) => f.preview_value !== null && f.preview_value !== undefined && f.preview_value !== "").map((f: any) => [f.key, f.preview_value])
      );
      await apiRequest(apiBase, token, "/api/v1/applications/profiles", "POST", {
        profile_name: profileDraftName,
        fields,
        is_default: reusableProfiles.length === 0,
        source: "application_builder",
      });
      setStatus("Reusable profile saved.");
      await loadReusableProfiles();
    } catch (error) {
      setStatus(String(error));
    }
  };

  return (
    <EnvironmentShell
      screenKey="tools"
      title="Application Builder"
      subtitle="Market-ready templates, instant send, smart autofill, and analytics."
      leftActions={buildRailActions("left", "tools")}
      rightActions={buildRailActions("right", "tools")}
      bottomActions={buildRailActions("bottom", "tools")}
    >
      <SurfaceScroll>
        <SectionCard title="Template Marketplace" subtitle="Public templates you can clone and customize in seconds.">
          <TextInput value={marketQuery} onChangeText={setMarketQuery} style={inputStyle} placeholder="Search templates" placeholderTextColor={browserTheme.textMuted} />
          <View style={ui.rowWrap}>
            {[...defaultCategories, ...marketCategories.map((c) => c.category).filter((c) => !defaultCategories.includes(c))].map((cat) => (
              <ActionChip key={cat} label={`${marketCategory === cat ? "• " : ""}${cat}`} onPress={() => setMarketCategory(cat)} />
            ))}
          </View>
          <View style={ui.rowWrap}>
            {marketTemplates.slice(0, 8).map((tpl) => (
              <View key={tpl.id} style={marketCardStyle}>
                <Text style={marketTitleStyle}>{tpl.name}</Text>
                <Text style={marketMetaStyle}>
                  {(tpl.market?.category || "General")} · {tpl.pricing_model}
                </Text>
                <Text style={marketMetaStyle}>
                  ${tpl.per_request_fee} {tpl.currency}
                </Text>
                <ActionChip label="Clone" onPress={() => cloneFromMarketplace(tpl.id)} />
              </View>
            ))}
          </View>
        </SectionCard>

        <SectionCard title="Request Templates" subtitle={status}>
          <View style={ui.rowWrap}>
            {templates.map((t) => (
              <Pressable
                key={t.id}
                onPress={() => setSelectedTemplateId(t.id)}
                style={{
                  borderRadius: 12,
                  borderWidth: 1,
                  borderColor: selectedTemplateId === t.id ? browserTheme.action : browserTheme.border,
                  backgroundColor: browserTheme.panelElevated,
                  paddingHorizontal: 10,
                  paddingVertical: 8,
                }}
              >
                <Text style={{ color: browserTheme.text, fontWeight: "700", fontSize: 12 }}>{t.name}</Text>
                <Text style={{ color: browserTheme.textMuted, fontSize: 11 }}>
                  {t.pricing_model} · {t.delivery_mode}
                </Text>
                <Text style={{ color: browserTheme.textMuted, fontSize: 11 }}>
                  {t.market?.is_public ? "Public" : "Private"} · {t.market?.category || "General"}
                </Text>
              </Pressable>
            ))}
          </View>
          <View style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, padding: 10, gap: 8 }}>
            <TextInput value={createInput.name} onChangeText={(v) => setCreateInput((p) => ({ ...p, name: v }))} style={inputStyle} placeholder="Template name" placeholderTextColor={browserTheme.textMuted} />
            <TextInput value={createInput.description} onChangeText={(v) => setCreateInput((p) => ({ ...p, description: v }))} style={inputStyle} placeholder="Description" placeholderTextColor={browserTheme.textMuted} />
            <TextInput value={createInput.category} onChangeText={(v) => setCreateInput((p) => ({ ...p, category: v }))} style={inputStyle} placeholder="Category" placeholderTextColor={browserTheme.textMuted} />
            <View style={ui.rowWrap}>
              {deliveryModes.map((m) => (
                <ActionChip key={m} label={`${createInput.delivery_mode === m ? "• " : ""}${m}`} onPress={() => setCreateInput((p) => ({ ...p, delivery_mode: m }))} />
              ))}
              {pricingModels.map((m) => (
                <ActionChip key={m} label={`${createInput.pricing_model === m ? "• " : ""}${m}`} onPress={() => setCreateInput((p) => ({ ...p, pricing_model: m }))} />
              ))}
            </View>
            {createInput.pricing_model === "per_request" ? (
              <TextInput value={createInput.per_request_fee} onChangeText={(v) => setCreateInput((p) => ({ ...p, per_request_fee: v }))} style={inputStyle} placeholder="Per-request fee" keyboardType="decimal-pad" placeholderTextColor={browserTheme.textMuted} />
            ) : null}
            <View style={ui.rowWrap}>
              <ActionChip label="Create Template" onPress={createTemplate} />
              <ActionChip label={selected?.market?.is_public ? "Unpublish" : "Publish"} onPress={() => updateMarketplaceSettings()} />
            </View>
          </View>
        </SectionCard>

        <SectionCard title="Canvas Builder" subtitle="Center builder · left fields · right settings">
          <View style={{ flexDirection: "row", gap: 10 }}>
            <View style={leftPaneStyle}>
              <Text style={paneTitleStyle}>Field List</Text>
              <ScrollView style={{ maxHeight: 280 }}>
                {selected?.fields?.map((field, idx) => (
                  <Pressable
                    key={`${field.key}-${idx}`}
                    onLongPress={() => setDraggingFieldIndex(idx)}
                    onPress={() => {
                      if (draggingFieldIndex !== null && draggingFieldIndex !== idx) {
                        moveFieldToIndex(draggingFieldIndex, idx);
                        setDraggingFieldIndex(null);
                      }
                    }}
                    style={{
                      borderRadius: 10,
                      borderWidth: 1,
                      borderColor: draggingFieldIndex === idx ? browserTheme.action : browserTheme.border,
                      backgroundColor: browserTheme.panelElevated,
                      padding: 8,
                      marginBottom: 6,
                    }}
                  >
                    <Text style={{ color: browserTheme.text, fontSize: 12, fontWeight: "700" }}>
                      {field.label} {field.required ? "*" : ""}
                    </Text>
                    <Text style={{ color: browserTheme.textMuted, fontSize: 11 }}>
                      {field.field_type} · {field.source_type}:{field.source_key || field.key}
                    </Text>
                  </Pressable>
                ))}
              </ScrollView>
              <Text style={{ color: browserTheme.textMuted, fontSize: 11 }}>
                Long press a field, then tap another position to reorder.
              </Text>
            </View>

            <View style={centerPaneStyle}>
              <Text style={paneTitleStyle}>Main Builder</Text>
              <TextInput value={newField.label} onChangeText={(v) => setNewField((p) => ({ ...p, label: v }))} style={inputStyle} placeholder="Field label" placeholderTextColor={browserTheme.textMuted} />
              <TextInput value={newField.key} onChangeText={(v) => setNewField((p) => ({ ...p, key: v }))} style={inputStyle} placeholder="Field key" placeholderTextColor={browserTheme.textMuted} />
              <View style={ui.rowWrap}>
                {fieldTypes.map((ft) => (
                  <ActionChip key={ft} label={`${newField.field_type === ft ? "• " : ""}${ft}`} onPress={() => setNewField((p) => ({ ...p, field_type: ft }))} />
                ))}
              </View>
              <View style={ui.rowWrap}>
                {sourceTypes.map((st) => (
                  <ActionChip key={st} label={`${newField.source_type === st ? "• " : ""}${st}`} onPress={() => setNewField((p) => ({ ...p, source_type: st }))} />
                ))}
              </View>
              <TextInput value={newField.source_key} onChangeText={(v) => setNewField((p) => ({ ...p, source_key: v }))} style={inputStyle} placeholder="Source key (vault field key)" placeholderTextColor={browserTheme.textMuted} />
              <View style={ui.rowWrap}>
                <ActionChip label={newField.required ? "Required: Yes" : "Required: No"} onPress={() => setNewField((p) => ({ ...p, required: !p.required }))} />
                <ActionChip label="Add Field" onPress={addField} />
                <ActionChip label="Suggest Fields" onPress={fetchFieldSuggestions} />
              </View>
              <View style={ui.rowWrap}>
                {fieldSuggestions.slice(0, 5).map((s, idx) => (
                  <ActionChip key={`${s.key}-${idx}`} label={`+ ${s.label}`} onPress={() => applySuggestion(s)} />
                ))}
              </View>

              <View style={ruleBoxStyle}>
                <Text style={{ color: browserTheme.textSoft, fontWeight: "700", fontSize: 12 }}>Logic Rules</Text>
                <TextInput value={newRule.name} onChangeText={(v) => setNewRule((p) => ({ ...p, name: v }))} style={inputStyle} placeholder="Rule name" placeholderTextColor={browserTheme.textMuted} />
                <TextInput value={newRule.condition.field} onChangeText={(v) => setNewRule((p) => ({ ...p, condition: { ...p.condition, field: v } }))} style={inputStyle} placeholder="Condition field key" placeholderTextColor={browserTheme.textMuted} />
                <TextInput value={newRule.condition.equals} onChangeText={(v) => setNewRule((p) => ({ ...p, condition: { ...p.condition, equals: v } }))} style={inputStyle} placeholder='Equals value (example: "business")' placeholderTextColor={browserTheme.textMuted} />
                <TextInput value={newRule.effect.require.join(",")} onChangeText={(v) => setNewRule((p) => ({ ...p, effect: { require: v.split(",").map((x) => x.trim()).filter(Boolean) } }))} style={inputStyle} placeholder="Require fields (comma separated)" placeholderTextColor={browserTheme.textMuted} />
                <ActionChip label="Add Rule" onPress={addRule} />
              </View>
            </View>

            <View style={rightPaneStyle}>
              <Text style={paneTitleStyle}>Quick Send + Profiles + Analytics</Text>
              <TextInput value={targetUserId} onChangeText={setTargetUserId} style={inputStyle} placeholder="Target user id (optional)" placeholderTextColor={browserTheme.textMuted} />
              <View style={ui.rowWrap}>
                {recentUsers.slice(0, 4).map((u) => (
                  <ActionChip key={u.user_id} label={u.username || u.user_id.slice(0, 8)} onPress={() => setTargetUserId(u.user_id)} />
                ))}
              </View>
              <View style={ui.rowWrap}>
                {vaultProfiles.map((vp) => (
                  <ActionChip key={vp.id} label={`${previewProfileId === vp.id ? "• " : ""}${vp.profile_name}`} onPress={() => setPreviewProfileId(vp.id)} />
                ))}
              </View>
              <View style={ui.rowWrap}>
                {reusableProfiles.map((rp) => (
                  <ActionChip key={rp.id} label={`${reusableProfileId === rp.id ? "• " : ""}${rp.profile_name}`} onPress={() => setReusableProfileId(rp.id)} />
                ))}
              </View>
              <ActionChip label="Preview User Flow" onPress={runPreview} />
              <View style={ui.rowWrap}>
                <ActionChip label="Quick Send" onPress={quickSend} />
                <ActionChip label="Send Direct" onPress={() => sendRequest("direct")} />
                <ActionChip label="Send Link" onPress={() => sendRequest("link")} />
                <ActionChip label="Send API" onPress={() => sendRequest("api")} />
              </View>
              {shareToken ? (
                <Text style={{ color: browserTheme.textMuted, fontSize: 11 }}>
                  Shareable token: {shareToken}
                </Text>
              ) : null}
              <TextInput value={profileDraftName} onChangeText={setProfileDraftName} style={inputStyle} placeholder="Reusable profile name" placeholderTextColor={browserTheme.textMuted} />
              <ActionChip label="Save Reusable Profile" onPress={saveReusableProfile} />
              <ActionChip label="Load Analytics" onPress={loadAnalytics} />
              <Text style={{ color: browserTheme.textMuted, fontSize: 11 }}>
                Monetization: {selected?.pricing_model || "subscription"} · {selected?.per_request_fee || 0} {selected?.currency || "USD"}
              </Text>
            </View>
          </View>

          <View style={outputBoxStyle}>
            <Text style={{ color: browserTheme.textSoft, fontWeight: "700", marginBottom: 6 }}>Preview Output</Text>
            <Text style={outputTextStyle}>{preview ? JSON.stringify(preview, null, 2) : "No preview yet."}</Text>
          </View>

          <View style={outputBoxStyle}>
            <Text style={{ color: browserTheme.textSoft, fontWeight: "700", marginBottom: 6 }}>Analytics</Text>
            <Text style={outputTextStyle}>{analytics ? JSON.stringify(analytics, null, 2) : "No analytics loaded."}</Text>
          </View>
        </SectionCard>
      </SurfaceScroll>
    </EnvironmentShell>
  );
}

const inputStyle = {
  borderRadius: 10,
  borderWidth: 1,
  borderColor: browserTheme.border,
  color: browserTheme.text,
  paddingHorizontal: 10,
  paddingVertical: 8,
  fontSize: 12,
};

const leftPaneStyle = { flex: 1, borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, padding: 10, gap: 8 };
const centerPaneStyle = { flex: 1.2, borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, padding: 10, gap: 8 };
const rightPaneStyle = { flex: 1, borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, padding: 10, gap: 8 };
const paneTitleStyle = { color: browserTheme.textSoft, fontWeight: "700" } as const;
const ruleBoxStyle = { borderRadius: 10, borderWidth: 1, borderColor: browserTheme.border, padding: 8, gap: 6 };
const outputBoxStyle = { borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, padding: 10, backgroundColor: browserTheme.panelElevated, marginTop: 10 };
const outputTextStyle = { color: browserTheme.textMuted, fontSize: 12 };
const marketCardStyle = { borderRadius: 12, padding: 10, minWidth: 180, backgroundColor: browserTheme.panelElevated, gap: 4 };
const marketTitleStyle = { color: browserTheme.text, fontWeight: "700", fontSize: 12 } as const;
const marketMetaStyle = { color: browserTheme.textMuted, fontSize: 11 };
