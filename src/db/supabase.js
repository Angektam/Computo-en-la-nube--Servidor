/**
 * supabase.js — Cliente de Supabase con la service_role key.
 * Solo se inicializa si SUPABASE_URL apunta a un servidor real (*.supabase.co).
 * En modo local (sin Supabase) exporta null para evitar el error de WebSocket.
 */

const url = process.env.SUPABASE_URL || '';
const esReal = url.includes('supabase.co');

let supabase = null;

if (esReal) {
  const { createClient } = require('@supabase/supabase-js');
  supabase = createClient(url, process.env.SUPABASE_SERVICE_KEY);
}

module.exports = supabase;
