/** أنواع البيانات المشتركة — مطابقة لعقود الخادم */

export interface User {
  id: string;
  phone_number: string;
  role: 'victim' | 'investigator' | 'supervisor' | 'admin';
  full_name?: string | null;
  governorate?: string | null;
  is_active: boolean;
  is_verified: boolean;
  created_at?: string | null;
}

export interface Tokens {
  access_token: string;
  refresh_token: string;
  token_type: string;
  expires_in: number;
  user?: User;
}

export interface ReportAnalysis {
  category: string;
  confidence: number;
  risk_level: string;
  is_extortion: boolean;
  probabilities: Record<string, number>;
  keywords: string[];
  threat_phrases: string[];
  recommendations?: string[];
  analysis_engine?: string;
}

export interface Evidence {
  id: string;
  report_id: string;
  file_hash: string;
  file_size: number;
  mime_type: string;
  verified: boolean;
  uploaded_at: string;
}

export interface CustodyEntry {
  action: string;
  actor: string;
  notes?: string | null;
  timestamp: string;
}

export interface Report {
  id: string;
  local_id: string;
  report_number?: string | null;
  victim_id?: string | null;
  sender_raw: string;
  sender_display: string;
  sender_phone?: string | null;
  sender_hash?: string | null;
  content: string;
  source_app: string;
  source_package?: string | null;
  analysis: ReportAnalysis;
  category: string;
  risk_level: string;
  confidence: number;
  message_timestamp: string;
  created_at: string;
  status: string;
  evidences?: Evidence[];
  custody?: CustodyEntry[];
}

export interface ReportList {
  items: Report[];
  total: number;
  page: number;
  page_size: number;
}

export interface Pattern {
  sender_key: string;
  sender_display: string;
  sender_phone?: string | null;
  victims: number;
  reports: number;
  apps: string[];
  first_seen?: string | null;
  last_seen?: string | null;
  span_days: number;
  dominant_category: string;
  avg_confidence: number;
  is_professional: boolean;
  score: number;
}

export interface Overview {
  total_reports: number;
  today_reports: number;
  total_victims: number;
  total_evidences: number;
  professional_senders: number;
  by_status: Record<string, number>;
  by_category: Record<string, number>;
  by_source: Record<string, number>;
  by_day: { date: string; count: number }[];
  top_senders: {
    sender_display: string;
    victims: number;
    reports: number;
    is_professional: boolean;
    score: number;
  }[];
}

export interface ForensicCase {
  id: string;
  case_number: string;
  report_id?: string | null;
  device_type?: string | null;
  device_identifier?: string | null;
  seizure_location?: string | null;
  seizure_at?: string | null;
  officers?: string | null;
  imaging_tool?: string | null;
  image_hash?: string | null;
  extracted_files_count?: number | null;
  extraction_notes?: string | null;
  erase_method?: string | null;
  erase_verification_hash?: string | null;
  erase_at?: string | null;
  status: string;
  created_at: string;
}

export interface LegalOrder {
  id: string;
  order_number: string;
  order_type: string;
  court_number: string;
  judge_name: string;
  target_type: string;
  target_ref?: string | null;
  related_report_id?: string | null;
  related_case_id?: string | null;
  status: string;
  issued_at: string;
  executed_at?: string | null;
  execution_notes?: string | null;
  cloud_order_number?: string | null;
}

export interface CloudOrder {
  id: string;
  order_number: string;
  legal_order_id?: string | null;
  report_id?: string | null;
  provider: string;
  provider_ref?: string | null;
  files_count: number;
  status: string;
  attempts: number;
  submitted_at: string;
  actioned_at?: string | null;
  notes?: string | null;
}

export interface BlocklistEntry {
  id: string;
  sender_hash: string;
  phone_number?: string | null;
  display_name: string;
  reason: string;
  related_report_id?: string | null;
  active: boolean;
  added_at: string;
}

export interface VictimNotification {
  id: string;
  victim_id: string;
  report_id?: string | null;
  type: string;
  title: string;
  message: string;
  created_at: string;
  read_at?: string | null;
}

export interface CaseRecord {
  id: string;
  case_number: string;
  title: string;
  description?: string | null;
  category?: string | null;
  priority: string;
  status: string;
  primary_victim_id?: string | null;
  assigned_to?: string | null;
  reports_count: number;
  victims_count: number;
  created_at: string;
  updated_at: string;
  closed_at?: string | null;
  reports?: {
    id: string;
    report_number?: string | null;
    sender_display: string;
    category: string;
    risk_level: string;
    status: string;
    created_at: string;
  }[];
  notes?: {
    id: string;
    author_name: string;
    content: string;
    is_internal: boolean;
    created_at: string;
  }[];
  updates?: {
    id: string;
    type: string;
    title: string;
    message: string;
    created_at: string;
  }[];
}

export const REPORT_STATUS_LABELS: Record<string, string> = {
  received: 'تم الاستلام',
  under_review: 'قيد المراجعة',
  investigating: 'قيد التحقيق',
  resolved: 'تم الحل',
  closed: 'مغلق',
  rejected: 'مرفوض',
  submitted: 'تم الإرسال',
  pending: 'قيد الإرسال',
  draft: 'مسودة',
  failed: 'فشل الإرسال',
};

export const RISK_LABELS: Record<string, string> = {
  none: 'لا يوجد',
  low: 'منخفض',
  medium: 'متوسط',
  high: 'عالي',
  critical: 'حرج',
};

export const SOURCE_LABELS: Record<string, string> = {
  sms: 'الرسائل النصية',
  'com.whatsapp': 'واتساب',
  'com.whatsapp.w4b': 'واتساب بزنس',
  'org.telegram.messenger': 'تيليجرام',
  'com.facebook.orca': 'ماسنجر',
  'com.instagram.android': 'إنستجرام',
  unknown: 'غير معروف',
};

export function sourceLabel(packageName: string): string {
  return SOURCE_LABELS[packageName] ?? packageName;
}
