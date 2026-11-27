export interface MessageSchema {
  app: {
    offlineBanner: string;
  };
  nav: {
    feed: string;
    diaperLog: string;
    bottleFeeding: string;
    breastfeeding: string;
    charts: string;
    growth: string;
    manageBabies: string;
    logout: string;
  };
  language: {
    label: string;
    en: string;
    ptBR: string;
  };
  theme: {
    label: string;
    light: string;
    dark: string;
    system: string;
  };
  feed: {
    heading: string;
    noLogsYet: string;
    empty: string;
    justNow: string;
    ago: string;
    loadingMore: string;
    avgPerDay: string;
    longGapHint: string;
  };
  charts: {
    heading: string;
    today: string;
    sevenDays: string;
    thirtyDays: string;
    custom: string;
    to: string;
    empty: string;
    export: string;
    exporting: string;
    exportError: string;
  };
  auth: {
    genericError: string;
    login: {
      title: string;
      email: string;
      password: string;
      rememberMe: string;
      submit: string;
      submitting: string;
      forgotPassword: string;
      noAccount: string;
      createAccount: string;
    };
    signup: {
      title: string;
      email: string;
      password: string;
      confirmPassword: string;
      submit: string;
      submitting: string;
      haveAccount: string;
      logIn: string;
    };
    forgotPassword: {
      title: string;
      email: string;
      submit: string;
      submitting: string;
      success: string;
      backToLogin: string;
    };
    resetPassword: {
      title: string;
      newPassword: string;
      confirmNewPassword: string;
      submit: string;
      submitting: string;
      requestNewLink: string;
    };
  };
  babies: {
    addTitle: string;
    editTitle: string;
    nameLabel: string;
    themeColorLabel: string;
    custom: string;
    useColor: string;
    addSubmit: string;
    saveSubmit: string;
    saving: string;
    cancel: string;
    edit: string;
    delete: string;
    confirmDelete: string;
    backHome: string;
    addFirstBaby: string;
    addBabyTitle: string;
  };
  diaperLog: {
    total: string;
    today: string;
    yesterday: string;
    sevenDays: string;
    thirtyDays: string;
    custom: string;
    to: string;
    quickLog: string;
    empty: string;
    peed: string;
    pooped: string;
    save: string;
    cancel: string;
    edit: string;
    delete: string;
    confirmDelete: string;
    toastLogged: string;
    undo: string;
    backHome: string;
  };
  bottleFeeding: {
    total: string;
    totalWater: string;
    totalFormula: string;
    today: string;
    yesterday: string;
    sevenDays: string;
    thirtyDays: string;
    custom: string;
    to: string;
    quickLog: string;
    quickLogDefaults: string;
    empty: string;
    amountSummary: string;
    water: string;
    formula: string;
    save: string;
    cancel: string;
    edit: string;
    delete: string;
    confirmDelete: string;
    toastLogged: string;
    undo: string;
    backHome: string;
  };
  breastfeedingLog: {
    total: string;
    today: string;
    yesterday: string;
    sevenDays: string;
    thirtyDays: string;
    custom: string;
    to: string;
    quickLog: string;
    empty: string;
    save: string;
    cancel: string;
    edit: string;
    delete: string;
    confirmDelete: string;
    toastLogged: string;
    undo: string;
    backHome: string;
  };
  growth: {
    heading: string;
    addTitle: string;
    editTitle: string;
    weightLabel: string;
    heightLabel: string;
    dateLabel: string;
    addSubmit: string;
    saveSubmit: string;
    saving: string;
    cancel: string;
    edit: string;
    delete: string;
    confirmDelete: string;
    empty: string;
    weightUnit: string;
    heightUnit: string;
    weightTrend: string;
    heightTrend: string;
    backHome: string;
    export: string;
    exporting: string;
    exportError: string;
  };
  serverErrors: {
    codes: {
      invalid_credentials: string;
      invalid_token: string;
      invalid_session: string;
      not_found: string;
      unauthenticated: string;
    };
  };
}

// Kept separate from MessageSchema (and never passed to `createI18n`)
// because these keys are the API's own literal English validation text
// ("can't be blank," "must be a hex color like #F5A9B8", …) — vue-i18n's
// path resolver is meant for dot-delimited keys like "babies.nameLabel",
// not arbitrary sentences with apostrophes, "#", or spaces in them. Looking
// these up as plain object properties sidesteps that entirely.
export interface ServerErrorMessages {
  messages: Record<
    | "can't be blank"
    | "must be a valid email"
    | "does not match password"
    | "has already been taken"
    | "must be a hex color like #F5A9B8"
    | "is invalid"
    | "weight or height must be present"
    | "must be greater than 0",
    string
  >;
  lengthAtLeast: string;
  lengthAtMost: string;
}

const en: MessageSchema = {
  app: {
    offlineBanner: "Offline — logs will sync when you're back online",
  },
  nav: {
    feed: "Home",
    diaperLog: "Diaper log",
    bottleFeeding: "Bottle feeding",
    breastfeeding: "Breastfeeding",
    charts: "Charts",
    growth: "Growth",
    manageBabies: "Manage babies",
    logout: "Log out",
  },
  language: {
    label: "Language",
    en: "EN",
    ptBR: "PT",
  },
  theme: {
    label: "Theme",
    light: "Light",
    dark: "Dark",
    system: "Auto",
  },
  feed: {
    heading: "Recent activity",
    noLogsYet: "No logs yet",
    empty: "No activity yet. Start logging to see it here.",
    justNow: "Just now",
    ago: "ago",
    loadingMore: "Loading more…",
    avgPerDay: "{avg}/day avg",
    longGapHint: "Longer than usual since the last one",
  },
  charts: {
    heading: "Trends",
    today: "Today",
    sevenDays: "7 days",
    thirtyDays: "30 days",
    custom: "Custom",
    to: "to",
    empty: "No data in this range yet.",
    export: "Export PDF",
    exporting: "Exporting…",
    exportError: "Couldn't export the PDF. Please try again.",
  },
  auth: {
    genericError: "something went wrong",
    login: {
      title: "Welcome back",
      email: "Email",
      password: "Password",
      rememberMe: "Remember me",
      submit: "Log in",
      submitting: "Logging in…",
      forgotPassword: "Forgot password?",
      noAccount: "New to BabyCheck?",
      createAccount: "Create an account",
    },
    signup: {
      title: "Create your account",
      email: "Email",
      password: "Password",
      confirmPassword: "Confirm password",
      submit: "Create account",
      submitting: "Creating account…",
      haveAccount: "Already have an account?",
      logIn: "Log in",
    },
    forgotPassword: {
      title: "Reset your password",
      email: "Email",
      submit: "Send reset link",
      submitting: "Sending…",
      success:
        "If an account exists for that email, we've sent instructions to reset your password.",
      backToLogin: "Back to log in",
    },
    resetPassword: {
      title: "Choose a new password",
      newPassword: "New password",
      confirmNewPassword: "Confirm new password",
      submit: "Save new password",
      submitting: "Saving…",
      requestNewLink: "Request a new link",
    },
  },
  babies: {
    addTitle: "Add a baby",
    editTitle: "Edit baby",
    nameLabel: "Name",
    themeColorLabel: "Theme color",
    custom: "Custom",
    useColor: "Use {color}",
    addSubmit: "Add baby",
    saveSubmit: "Save changes",
    saving: "Saving…",
    cancel: "Cancel",
    edit: "Edit",
    delete: "Delete",
    confirmDelete: "Remove {name}? This can't be undone.",
    backHome: "Back home",
    addFirstBaby: "+ Add your first baby",
    addBabyTitle: "Add a baby",
  },
  diaperLog: {
    total: "diaper changes",
    today: "Today",
    yesterday: "Yesterday",
    sevenDays: "7 days",
    thirtyDays: "30 days",
    custom: "Custom",
    to: "to",
    quickLog: "Log diaper change",
    empty: "No diaper changes in this range yet.",
    peed: "Peed",
    pooped: "Pooped",
    save: "Save",
    cancel: "Cancel",
    edit: "Edit",
    delete: "Delete",
    confirmDelete: "Delete this diaper change? This can't be undone.",
    toastLogged: "Diaper logged",
    undo: "Undo",
    backHome: "Back home",
  },
  bottleFeeding: {
    total: "bottle feedings",
    totalWater: "water",
    totalFormula: "formula",
    today: "Today",
    yesterday: "Yesterday",
    sevenDays: "7 days",
    thirtyDays: "30 days",
    custom: "Custom",
    to: "to",
    quickLog: "Log bottle feeding",
    quickLogDefaults: "Quick-log defaults to {water}ml · {formula}g",
    empty: "No bottle feedings in this range yet.",
    amountSummary: "{water}ml · {formula}g",
    water: "Water (ml)",
    formula: "Formula (g)",
    save: "Save",
    cancel: "Cancel",
    edit: "Edit",
    delete: "Delete",
    confirmDelete: "Delete this bottle feeding? This can't be undone.",
    toastLogged: "Bottle feeding logged",
    undo: "Undo",
    backHome: "Back home",
  },
  breastfeedingLog: {
    total: "breastfeeding sessions",
    today: "Today",
    yesterday: "Yesterday",
    sevenDays: "7 days",
    thirtyDays: "30 days",
    custom: "Custom",
    to: "to",
    quickLog: "Log breastfeeding",
    empty: "No breastfeeding sessions in this range yet.",
    save: "Save",
    cancel: "Cancel",
    edit: "Edit",
    delete: "Delete",
    confirmDelete: "Delete this breastfeeding session? This can't be undone.",
    toastLogged: "Breastfeeding logged",
    undo: "Undo",
    backHome: "Back home",
  },
  growth: {
    heading: "Growth measurements",
    addTitle: "Add a measurement",
    editTitle: "Edit measurement",
    weightLabel: "Weight (kg)",
    heightLabel: "Height (cm)",
    dateLabel: "Date",
    addSubmit: "Add measurement",
    saveSubmit: "Save changes",
    saving: "Saving…",
    cancel: "Cancel",
    edit: "Edit",
    delete: "Delete",
    confirmDelete: "Delete this measurement? This can't be undone.",
    empty: "No growth measurements recorded yet.",
    weightUnit: "kg",
    heightUnit: "cm",
    weightTrend: "Weight trend",
    heightTrend: "Height trend",
    backHome: "Back home",
    export: "Export PDF",
    exporting: "Exporting…",
    exportError: "Couldn't export the PDF. Please try again.",
  },
  serverErrors: {
    codes: {
      invalid_credentials: "invalid email or password",
      invalid_token: "invalid or expired token",
      invalid_session: "invalid or expired session",
      not_found: "not found",
      unauthenticated: "unauthenticated",
    },
  },
};

export const enServerErrorMessages: ServerErrorMessages = {
  messages: {
    "can't be blank": "can't be blank",
    "must be a valid email": "must be a valid email",
    "does not match password": "does not match password",
    "has already been taken": "has already been taken",
    "must be a hex color like #F5A9B8": "must be a hex color like #F5A9B8",
    "is invalid": "is invalid",
    "weight or height must be present": "enter a weight or a height",
    "must be greater than 0": "must be greater than 0",
  },
  lengthAtLeast: "should be at least {count} character(s)",
  lengthAtMost: "should be at most {count} character(s)",
};

export default en;
