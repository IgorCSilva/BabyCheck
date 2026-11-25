import type { MessageSchema, ServerErrorMessages } from "./en";

const ptBR: MessageSchema = {
  nav: {
    diaperLog: "Registro de fraldas",
    manageBabies: "Gerenciar bebês",
  },
  language: {
    label: "Idioma",
    en: "EN",
    ptBR: "PT",
  },
  home: {
    welcome: "Bem-vindo(a), {email}",
    helper:
      "O registro de mamadeira e amamentação chega nas próximas etapas — trocas de fralda já estão disponíveis.",
    goToDiaperLog: "Ir para o registro de fraldas",
    logout: "Sair",
  },
  auth: {
    genericError: "algo deu errado",
    login: {
      title: "Bem-vindo(a) de volta",
      email: "Email",
      password: "Senha",
      rememberMe: "Lembrar de mim",
      submit: "Entrar",
      submitting: "Entrando…",
      forgotPassword: "Esqueceu a senha?",
      noAccount: "Novo(a) no BabyCheck?",
      createAccount: "Criar uma conta",
    },
    signup: {
      title: "Crie sua conta",
      email: "Email",
      password: "Senha",
      confirmPassword: "Confirme a senha",
      submit: "Criar conta",
      submitting: "Criando conta…",
      haveAccount: "Já tem uma conta?",
      logIn: "Entrar",
    },
    forgotPassword: {
      title: "Redefina sua senha",
      email: "Email",
      submit: "Enviar link de redefinição",
      submitting: "Enviando…",
      success:
        "Se existir uma conta com esse email, enviamos instruções para redefinir sua senha.",
      backToLogin: "Voltar para o login",
    },
    resetPassword: {
      title: "Escolha uma nova senha",
      newPassword: "Nova senha",
      confirmNewPassword: "Confirme a nova senha",
      submit: "Salvar nova senha",
      submitting: "Salvando…",
      requestNewLink: "Solicitar um novo link",
    },
  },
  babies: {
    addTitle: "Adicionar bebê",
    editTitle: "Editar bebê",
    nameLabel: "Nome",
    themeColorLabel: "Cor do tema",
    custom: "Personalizada",
    useColor: "Usar {color}",
    addSubmit: "Adicionar bebê",
    saveSubmit: "Salvar alterações",
    saving: "Salvando…",
    cancel: "Cancelar",
    edit: "Editar",
    delete: "Excluir",
    confirmDelete: "Remover {name}? Isso não pode ser desfeito.",
    backHome: "Voltar ao início",
    addFirstBaby: "+ Adicione seu primeiro bebê",
    addBabyTitle: "Adicionar bebê",
  },
  diaperLog: {
    total: "trocas de fralda",
    today: "Hoje",
    yesterday: "Ontem",
    sevenDays: "7 dias",
    thirtyDays: "30 dias",
    custom: "Personalizado",
    to: "até",
    quickLog: "Registrar troca de fralda",
    empty: "Nenhuma troca de fralda neste período ainda.",
    peed: "Xixi",
    pooped: "Cocô",
    save: "Salvar",
    cancel: "Cancelar",
    edit: "Editar",
    delete: "Excluir",
    confirmDelete: "Excluir esta troca de fralda? Isso não pode ser desfeito.",
    toastLogged: "Fralda registrada",
    undo: "Desfazer",
    backHome: "Voltar ao início",
  },
  serverErrors: {
    codes: {
      invalid_credentials: "email ou senha inválidos",
      invalid_token: "token inválido ou expirado",
      invalid_session: "sessão inválida ou expirada",
      not_found: "não encontrado",
      unauthenticated: "não autenticado",
    },
  },
};

export const ptBRServerErrorMessages: ServerErrorMessages = {
  messages: {
    "can't be blank": "não pode ficar em branco",
    "must be a valid email": "deve ser um email válido",
    "does not match password": "não corresponde à senha",
    "has already been taken": "já está em uso",
    "must be a hex color like #F5A9B8": "deve ser uma cor hexadecimal como #F5A9B8",
    "is invalid": "é inválido",
  },
  lengthAtLeast: "deve ter pelo menos {count} caractere(s)",
  lengthAtMost: "deve ter no máximo {count} caractere(s)",
};

export default ptBR;
