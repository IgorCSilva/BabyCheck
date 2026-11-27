import { beforeEach, describe, expect, it } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { mount } from "@vue/test-utils";
import { createI18n } from "vue-i18n";
import en from "@/i18n/en";
import type { MessageSchema } from "@/i18n/en";
import OfflineBanner from "./OfflineBanner.vue";
import { useOutboxStore } from "@/stores/outbox";

function mountBanner() {
  const i18n = createI18n<[MessageSchema], "en", false>({
    legacy: false,
    locale: "en",
    messages: { en },
  });
  return mount(OfflineBanner, { global: { plugins: [i18n] } });
}

describe("OfflineBanner", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it("stays hidden while online", () => {
    const outbox = useOutboxStore();
    outbox.online = true;

    const wrapper = mountBanner();
    expect(wrapper.find(".offline-banner").exists()).toBe(false);
  });

  it("shows the calm cream banner once offline", () => {
    const outbox = useOutboxStore();
    outbox.online = false;

    const wrapper = mountBanner();
    expect(wrapper.find(".offline-banner").text()).toBe(en.app.offlineBanner);
  });
});
