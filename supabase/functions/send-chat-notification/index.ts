// supabase/functions/send-chat-notification/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { message_id, conversation_id } = await req.json();
    console.log("📨 Notification request:", { message_id, conversation_id });

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // Récupérer le message
    const { data: message } = await supabase
      .from("messages")
      .select("content, sender_id")
      .eq("id", message_id)
      .single();

    if (!message) {
      throw new Error("Message not found");
    }

    // Récupérer la conversation
    const { data: conversation } = await supabase
      .from("conversations")
      .select("patient_id, pharmacy_id")
      .eq("id", conversation_id)
      .single();

    if (!conversation) {
      throw new Error("Conversation not found");
    }

    // Déterminer le destinataire (celui qui n'a pas envoyé)
    const senderId = message.sender_id;
    const recipientId = conversation.patient_id === senderId
      ? conversation.pharmacy_id
      : conversation.patient_id;

    if (!recipientId) {
      console.log("⚠️ No recipient found");
      return new Response(JSON.stringify({ success: true, skipped: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }

    // Récupérer le token FCM du destinataire
    const { data: recipient } = await supabase
      .from("users")
      .select("fcm_token, full_name")
      .eq("id", recipientId)
      .single();

    if (!recipient?.fcm_token) {
      console.log("⚠️ Recipient has no FCM token");
      return new Response(JSON.stringify({ success: true, skipped: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }

    // Envoyer via Firebase (simplifié)
    const notificationPayload = {
      to: recipient.fcm_token,
      notification: {
        title: "🔔 Nouveau message",
        body: message.content.length > 50 
          ? `${message.content.substring(0, 50)}...` 
          : message.content,
      },
      data: {
        conversation_id: conversation_id,
        type: "new_message",
      },
    };

    console.log("📤 Sending FCM notification...");
    
    // Note: Pour Firebase, vous devez configurer l'authentification
    // Pour l'instant, on log juste
    console.log("✅ Notification prepared:", notificationPayload);

    return new Response(JSON.stringify({ 
      success: true,
      notification: notificationPayload 
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error) {
    console.error("❌ Error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});