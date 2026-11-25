import { createI18n } from "vue-i18n";
import en, { enServerErrorMessages } from "./en";
import ptBR, { ptBRServerErrorMessages } from "./pt-BR";
import type { MessageSchema, ServerErrorMessages } from "./en";
import type { ApiError } from "@/lib/api";

export type Locale = "en" | "pt-BR";

const STORAGE_KEY = "babycheck.locale";
const LOCALES: Locale[] = ["en", "pt-BR"];

function detectInitialLocale(): Locale {
  const stored = localStorage.getItem(STORAGE_KEY);
  if (stored && (LOCALES as string[]).includes(stored)) return stored as Locale;

  const browserLanguage = typeof navigator !== "undefined" ? navigator.language : "";
  return browserLanguage.toLowerCase().startsWith("pt") ? "pt-BR" : "en";
}

export const i18n = createI18n<[MessageSchema], Locale, false>({
  legacy: false,
  globalInjection: true,
  locale: detectInitialLocale(),
  fallbackLocale: "en",
  messages: { en, "pt-BR": ptBR },
});

if (typeof document !== "undefined") {
  document.documentElement.lang = i18n.global.locale.value;
}

export function setLocale(locale: Locale) {
  i18n.global.locale.value = locale;
  localStorage.setItem(STORAGE_KEY, locale);
  if (typeof document !== "undefined") document.documentElement.lang = locale;
}

const serverErrorMessagesByLocale: Record<Locale, ServerErrorMessages> = {
  en: enServerErrorMessages,
  "pt-BR": ptBRServerErrorMessages,
};

const LENGTH_AT_LEAST = /^should be at least (\d+) character\(s\)$/;
const LENGTH_AT_MOST = /^should be at most (\d+) character\(s\)$/;

// The API only ever sends back English validation text (see the Ecto
// changesets in api/lib/api) — this maps that finite, known set of literal
// messages to the active locale instead of requiring the backend to be
// locale-aware. Anything unrecognized (there shouldn't be any) is shown as
// returned rather than silently swallowed.
function translateServerMessage(message: string): string {
  const table = serverErrorMessagesByLocale[i18n.global.locale.value];
  const known = table.messages as Record<string, string | undefined>;
  if (known[message]) return known[message] as string;

  const atLeast = message.match(LENGTH_AT_LEAST);
  if (atLeast) return table.lengthAtLeast.replace("{count}", atLeast[1]);

  const atMost = message.match(LENGTH_AT_MOST);
  if (atMost) return table.lengthAtMost.replace("{count}", atMost[1]);

  return message;
}

export function translateFieldErrors(
  fieldErrors: Record<string, string[]>,
): Record<string, string[]> {
  const translated: Record<string, string[]> = {};
  for (const [field, messages] of Object.entries(fieldErrors)) {
    translated[field] = messages.map(translateServerMessage);
  }
  return translated;
}

export function translateApiError(error: ApiError): string {
  const { t, te } = i18n.global;

  if (error.code) {
    const codeKey = `serverErrors.codes.${error.code}`;
    if (te(codeKey)) return t(codeKey);
  }

  return translateServerMessage(error.message);
}
