/* © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung. */
/* ARGUS — Zentrale Backend-Konfiguration
 *
 * Dies ist die EINZIGE Stelle, an der die Backend-Instanz (Supabase-URL +
 * Anon-Key) eingestellt wird. Beim Self-Hosting (eigene Instanz, siehe
 * docs/SELF-HOSTING.md) wird ausschließlich diese Datei ausgetauscht —
 * keine Codeänderung in index.html oder der Leitungs-Seite nötig.
 *
 * WICHTIG: Hier stehen NUR öffentliche Werte (Projekt-URL + Anon-Key, beide
 * ohnehin im Client sichtbar). NIEMALS Service-Keys, JWT-Secrets oder andere
 * Geheimnisse eintragen — diese Datei wird an jeden Browser ausgeliefert.
 */
window.ARGUS_CONFIG = {
  url: 'https://sehuosjyjmrpzcqrelej.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlaHVvc2p5am1ycHpjcXJlbGVqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA0Mjk1MzksImV4cCI6MjA5NjAwNTUzOX0.G0DuJmeJBQwTLK8n4m4PVFSf2eNStZy_F0gIouMxIuo'
};
