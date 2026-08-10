import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const NVIDIA_API_BASE = "https://integrate.api.nvidia.com/v1/chat/completions";
const DEFAULT_MODEL = Deno.env.get("NVIDIA_MODEL") ??
  "nvidia/llama-3.1-nemotron-nano-8b-v1";

type DraftHelpRequestPayload = {
  taskType: "draft_help_request";
  prompt: string;
};

type ImproveAnnouncementPayload = {
  taskType: "improve_announcement";
  title: string;
  message: string;
};

type Payload = DraftHelpRequestPayload | ImproveAnnouncementPayload;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const apiKey = Deno.env.get("NVIDIA_API_KEY");
  if (!apiKey) {
    return json(
      {
        error: "nvidia_not_configured",
        message:
          "Set NVIDIA_API_KEY in Supabase Edge Function secrets before using AI.",
      },
      503,
    );
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return json({ error: "missing_authorization" }, 401);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    },
  );

  const { data: userResult, error: userError } = await supabase.auth.getUser();
  if (userError || !userResult.user) {
    return json({ error: "unauthorized" }, 401);
  }

  let payload: Payload;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  try {
    switch (payload.taskType) {
      case "draft_help_request":
        return await handleDraftHelpRequest(payload, apiKey);
      case "improve_announcement":
        return await handleImproveAnnouncement(payload, apiKey);
      default:
        return json({ error: "unsupported_task_type" }, 400);
    }
  } catch (error) {
    return json(
      {
        error: "ai_request_failed",
        message: error instanceof Error ? error.message : String(error),
      },
      500,
    );
  }
});

async function handleDraftHelpRequest(
  payload: DraftHelpRequestPayload,
  apiKey: string,
) {
  const systemPrompt =
    "You help parents create childcare and transport help requests. Return strict JSON only with keys: title, category, description, pickupAddress, dropoffAddress, specialInstructions. category must be one of: school_pickup, school_dropoff, sports_practice, doctor_appointment, playdate, babysitting, overnight, emergency, event, party, other.";

  const userPrompt =
    `Convert the following rough request into a structured draft:\n${payload.prompt}`;

  const content = await callNvidiaChat(apiKey, [
    { role: "system", content: systemPrompt },
    { role: "user", content: userPrompt },
  ]);

  const parsed = safeJsonParse(content);
  if (parsed == null || typeof parsed !== "object") {
    throw new Error("The model did not return valid JSON.");
  }

  return json({
    taskType: payload.taskType,
    model: DEFAULT_MODEL,
    draft: parsed,
  });
}

async function handleImproveAnnouncement(
  payload: ImproveAnnouncementPayload,
  apiKey: string,
) {
  const systemPrompt =
    "You improve short community announcements for a family village app. Return strict JSON only with keys: title, message. Keep the tone practical, warm, and concise.";

  const userPrompt =
    `Improve this village announcement.\nTitle: ${payload.title}\nMessage: ${payload.message}`;

  const content = await callNvidiaChat(apiKey, [
    { role: "system", content: systemPrompt },
    { role: "user", content: userPrompt },
  ]);

  const parsed = safeJsonParse(content);
  if (
    parsed == null || typeof parsed !== "object" || !("title" in parsed) ||
    !("message" in parsed)
  ) {
    throw new Error("The model did not return a valid announcement payload.");
  }

  return json({
    taskType: payload.taskType,
    model: DEFAULT_MODEL,
    draft: parsed,
  });
}

async function callNvidiaChat(
  apiKey: string,
  messages: Array<{ role: string; content: string }>,
) {
  const response = await fetch(NVIDIA_API_BASE, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: DEFAULT_MODEL,
      messages,
      temperature: 0.2,
      top_p: 0.9,
      max_tokens: 700,
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`NVIDIA API ${response.status}: ${text}`);
  }

  const data = await response.json();
  return data?.choices?.[0]?.message?.content?.trim() ?? "";
}

function safeJsonParse(text: string) {
  try {
    return JSON.parse(text);
  } catch {
    const match = text.match(/\{[\s\S]*\}/);
    if (!match) return null;
    try {
      return JSON.parse(match[0]);
    } catch {
      return null;
    }
  }
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders,
    },
  });
}
