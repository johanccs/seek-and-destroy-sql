export function PrivacyView() {
  return (
    <div className="legal-view">
      <h2>Privacy Policy</h2>
      <p className="muted legal-updated">Last updated: 27 July 2026</p>

      <p>
        Seek &amp; Destroy is a free, no-signup learning tool. There are no user accounts, and
        we do not knowingly collect any information that identifies you personally. This page
        explains, plainly, what data the app does handle.
      </p>

      <h3>Lesson progress</h3>
      <p>
        Which lessons you've solved, and your best logical-reads/duration for each, is stored
        in a small database on the server (<code>AppMeta</code>) so the dashboard and
        checkmarks work. It is not linked to your name, email, or any account — there isn't
        one. Because the app has no login, this progress is shared by everyone using the same
        deployment rather than kept separate per visitor.
      </p>

      <h3>The AI tutor ("Sarge")</h3>
      <p>
        When you use the tutor chat panel, the message you type, the current lesson's title,
        level, topics and narrative, and your prior chat history for that lesson are sent to{" "}
        <a href="https://openrouter.ai" target="_blank" rel="noopener">OpenRouter</a>, a
        third-party API that routes the request to an underlying AI model, in order to
        generate an answer. That data leaves this app and is handled under OpenRouter's own
        privacy policy and that of whichever model answers the request. Your SQL editor
        contents are not sent automatically — but if you paste code into a tutor message, that
        code is sent along with it. Don't paste secrets, credentials, or anything sensitive
        into a tutor message.
      </p>

      <h3>Your SQL queries</h3>
      <p>
        The T-SQL you write runs against a real SQL Server instance used only by this app, so
        it can grade your solution and show you real execution plans and statistics. It is not
        sent anywhere else.
      </p>

      <h3>Local browser storage</h3>
      <p>
        Your theme choice (dark/light) and sidebar width are saved in your browser's local
        storage so they're remembered next time. Neither is sent to the server.
      </p>

      <h3>Server logs</h3>
      <p>
        Like any hosted website, the underlying infrastructure (Microsoft Azure) may keep
        standard web server access logs (e.g. IP address, timestamp, requested page) for
        operational and security purposes. We do not use analytics or tracking cookies.
      </p>

      <h3>Questions</h3>
      <p>
        This is a small, independently run project. If you have a question about this policy,
        reach out at <a href="mailto:johan.ccs@gmail.com">johan.ccs@gmail.com</a>.
      </p>
    </div>
  );
}
