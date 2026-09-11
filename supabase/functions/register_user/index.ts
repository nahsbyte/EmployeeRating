// Edge Function: register_user
// Membuat user Auth + memasukkan baris ke public.profiles
// Hanya boleh dipanggil oleh user dengan role super_admin atau admin.

import { serve } from "https://deno.land/std@0.181.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.5";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return new Response("Unauthorized", { status: 401 });
  }
  const jwt = authHeader.replace("Bearer ", "").trim();

  // Pastikan pemanggil adalah super_admin/admin
  const { data: callerData, error: callerErr } = await supabaseAdmin.auth.getUser(jwt);
  if (callerErr || !callerData.user) {
    return new Response("Invalid token", { status: 401 });
  }

  const callerId = callerData.user.id;
  const { data: profileCaller, error: profileErr } = await supabaseAdmin
    .from("profiles")
    .select("role")
    .eq("user_id", callerId)
    .maybeSingle();

  const callerRole = profileCaller?.role;
  if (profileErr || !callerRole || !["super_admin", "admin"].includes(callerRole)) {
    return new Response("Forbidden", { status: 403 });
  }

  try {
    const {
      email,
      password,
      role,
      class_id,
      full_name,
      student_id,
      phone,
      address,
      identity_number,
      gender,
      is_active,
    } = await req.json();
    if (!email || !password || !role) {
      return new Response("Missing fields", { status: 400 });
    }

    const allowedRoles = ["siswa", "wali", "admin", "super_admin"];
    if (!allowedRoles.includes(role)) {
      return new Response("Invalid role", { status: 400 });
    }

    // Admin tidak boleh membuat super_admin
    if (callerRole === "admin" && role === "super_admin") {
      return new Response("Admin cannot create super_admin", { status: 403 });
    }

    let resolvedFullName = (full_name ?? "").toString().trim() || email.split("@")[0];
    const resolvedPhone = (phone ?? "").toString().trim() || null;
    const resolvedAddress = (address ?? "").toString().trim() || null;
    const resolvedIdentity = (identity_number ?? "").toString().trim() || null;
    const resolvedGender = (gender ?? "").toString().trim() || null;
    const resolvedActive = typeof is_active === "boolean" ? is_active : true;
    let studentId: string | null = null;
    if (role === "siswa") {
      if (!student_id) {
        return new Response("Missing student_id", { status: 400 });
      }
      const { data: studentMatch } = await supabaseAdmin
        .from("student")
        .select("student_id, student_name, student_class")
        .eq("student_id", student_id)
        .maybeSingle();
      if (!studentMatch) {
        return new Response("Invalid student_id", { status: 400 });
      }
      if (class_id && studentMatch.student_class?.toString().trim() !== class_id.toString().trim()) {
        return new Response("student_id does not match class_id", { status: 400 });
      }
      studentId = studentMatch.student_id;
      if (studentMatch.student_name) {
        resolvedFullName = studentMatch.student_name;
      }
    }

    const { data: userResp, error: createErr } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: resolvedFullName, name: resolvedFullName, role },
    });
    if (createErr || !userResp?.user) {
      return new Response(`Create user error: ${createErr?.message}`, { status: 400 });
    }

    const userId = userResp.user.id;
    const { error: profErr } = await supabaseAdmin.from("profiles").upsert({
      user_id: userId,
      role,
      class_id: class_id ?? null,
      full_name: resolvedFullName,
      student_id: studentId,
      phone: resolvedPhone,
      address: resolvedAddress,
      identity_number: resolvedIdentity,
      gender: resolvedGender,
      is_active: resolvedActive,
    });
    if (profErr) {
      return new Response(`Profiles insert error: ${profErr.message}`, { status: 400 });
    }

    return new Response(JSON.stringify({ user_id: userId }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(`Unexpected error: ${e}`, { status: 500 });
  }
});
