defmodule Api.Accounts.UserNotifier do
  import Swoosh.Email

  alias Api.Mailer

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"BabyCheck", "no-reply@babycheck.app"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Reset your BabyCheck password", """
    Hi,

    Someone asked to reset your BabyCheck password. If this was you, click the link below:

    #{url}

    This link is valid for one hour. If you didn't request this, you can safely ignore this email.
    """)
  end
end
