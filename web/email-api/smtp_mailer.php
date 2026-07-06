<?php
declare(strict_types=1);

function tpk_text($value, string $fallback = ''): string
{
    if ($value === null) {
        return $fallback;
    }
    $s = trim((string) $value);
    return $s === '' ? $fallback : $s;
}

function tpk_format_from(string $senderName, string $fromEmail): string
{
    $name = str_replace('"', '', tpk_text($senderName, 'TestprepKart'));
    $email = tpk_text($fromEmail);
    if ($email === '') {
        throw new RuntimeException('fromEmail is required');
    }
    return "\"{$name}\" <{$email}>";
}

/**
 * @param array<string, mixed> $settings
 * @param array{to:string,subject:string,html:string} $message
 */
function tpk_send_smtp(array $settings, array $message): void
{
    $smtp = is_array($settings['smtp'] ?? null) ? $settings['smtp'] : [];
    $host = tpk_text($smtp['host'] ?? '');
    if ($host === '') {
        throw new RuntimeException('SMTP host is not configured');
    }

    $port = (int) ($smtp['port'] ?? 587);
    $username = tpk_text($smtp['username'] ?? '');
    $password = tpk_text($smtp['password'] ?? '');
    $secure = $port === 465;

    $from = tpk_format_from(
        tpk_text($settings['senderName'] ?? '', 'TestprepKart'),
        tpk_text($settings['fromEmail'] ?? '')
    );
    $replyTo = tpk_text($settings['replyToEmail'] ?? '');

    $mailer = new TpkSmtpMailer($host, $port, $secure, $username, $password);
    $mailer->sendMail(
        $from,
        $message['to'],
        $message['subject'],
        $message['html'],
        $replyTo !== '' ? $replyTo : null
    );
}

final class TpkSmtpMailer
{
    private $socket;

    public function __construct(
        private readonly string $host,
        private readonly int $port,
        private readonly bool $secure,
        private readonly string $username,
        private readonly string $password
    ) {
    }

    public function sendMail(
        string $from,
        string $to,
        string $subject,
        string $html,
        ?string $replyTo
    ): void {
        $this->connect();
        $this->expect(220);
        $this->command('EHLO neetappadmin.satlas.org');
        $this->expect(250);

        if (!$this->secure && $this->port === 587) {
            $this->command('STARTTLS');
            $this->expect(220);
            if (!stream_socket_enable_crypto($this->socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
                throw new RuntimeException('STARTTLS failed');
            }
            $this->command('EHLO neetappadmin.satlas.org');
            $this->expect(250);
        }

        if ($this->username !== '' && $this->password !== '') {
            $this->command('AUTH LOGIN');
            $this->expect(334);
            $this->command(base64_encode($this->username));
            $this->expect(334);
            $this->command(base64_encode($this->password));
            $this->expect(235);
        }

        if (!preg_match('/<([^>]+)>/', $from, $fromMatch)) {
            throw new RuntimeException('Invalid from address');
        }
        $fromEmail = $fromMatch[1];

        $this->command("MAIL FROM:<{$fromEmail}>");
        $this->expect(250);
        $this->command("RCPT TO:<{$to}>");
        $this->expect(250);
        $this->command('DATA');
        $this->expect(354);

        $headers = [
            "From: {$from}",
            "To: {$to}",
            "Subject: {$subject}",
            'MIME-Version: 1.0',
            'Content-Type: text/html; charset=UTF-8',
            'Content-Transfer-Encoding: 8bit',
        ];
        if ($replyTo !== null) {
            $headers[] = "Reply-To: {$replyTo}";
        }

        $body = implode("\r\n", $headers) . "\r\n\r\n" . $html . "\r\n.";
        fwrite($this->socket, $body . "\r\n");
        $this->expect(250);
        $this->command('QUIT');
        fclose($this->socket);
    }

    private function connect(): void
    {
        $target = $this->secure
            ? "ssl://{$this->host}:{$this->port}"
            : "tcp://{$this->host}:{$this->port}";
        $errno = 0;
        $errstr = '';
        $this->socket = @stream_socket_client(
            $target,
            $errno,
            $errstr,
            20,
            STREAM_CLIENT_CONNECT
        );
        if (!$this->socket) {
            throw new RuntimeException("SMTP connect failed: {$errstr} ({$errno})");
        }
        stream_set_timeout($this->socket, 20);
    }

    private function command(string $line): void
    {
        fwrite($this->socket, $line . "\r\n");
    }

    private function expect(int $code): void
    {
        $response = '';
        while (($line = fgets($this->socket, 515)) !== false) {
            $response .= $line;
            if (isset($line[3]) && $line[3] === ' ') {
                break;
            }
        }
        $got = (int) substr(trim($response), 0, 3);
        if ($got !== $code) {
            throw new RuntimeException("SMTP expected {$code}, got: " . trim($response));
        }
    }
}
