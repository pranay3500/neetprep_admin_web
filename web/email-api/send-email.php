<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

$allowed = [
    'https://neetappadmin.satlas.org',
    'http://127.0.0.1:8081',
    'http://localhost:8081',
];
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if (in_array($origin, $allowed, true)) {
    header("Access-Control-Allow-Origin: {$origin}");
}
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    http_response_code(405);
    echo json_encode(['ok' => false, 'error' => 'POST required']);
    exit;
}

require_once __DIR__ . '/smtp_mailer.php';

function tpk_json_input(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') {
        return [];
    }
    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : [];
}

function tpk_send_sendgrid(array $settings, array $message): void
{
    $api = is_array($settings['api'] ?? null) ? $settings['api'] : [];
    $apiKey = tpk_text($api['apiKey'] ?? '');
    if ($apiKey === '') {
        throw new RuntimeException('SendGrid API key is not configured');
    }
    $endpoint = tpk_text($api['endpoint'] ?? '', 'https://api.sendgrid.com/v3/mail/send');
    $payload = json_encode([
        'personalizations' => [['to' => [['email' => $message['to']]]]],
        'from' => [
            'email' => tpk_text($settings['fromEmail'] ?? ''),
            'name' => tpk_text($settings['senderName'] ?? '', 'TestprepKart'),
        ],
        'reply_to' => tpk_text($settings['replyToEmail'] ?? '') !== ''
            ? ['email' => tpk_text($settings['replyToEmail'] ?? '')]
            : null,
        'subject' => $message['subject'],
        'content' => [['type' => 'text/html', 'value' => $message['html']]],
    ]);

    $ch = curl_init($endpoint);
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_HTTPHEADER => [
            'Authorization: Bearer ' . $apiKey,
            'Content-Type: application/json',
        ],
        CURLOPT_POSTFIELDS => $payload,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 45,
    ]);
    $response = curl_exec($ch);
    $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    if ($status < 200 || $status >= 300) {
        throw new RuntimeException("SendGrid failed: {$status} {$response}");
    }
}

try {
    $body = tpk_json_input();
    $settings = is_array($body['settings'] ?? null) ? $body['settings'] : [];
    $to = tpk_text($body['to'] ?? '');
    $subject = tpk_text($body['subject'] ?? '');
    $html = tpk_text($body['html'] ?? '');

    if ($to === '' || $subject === '' || $html === '') {
        http_response_code(400);
        echo json_encode(['ok' => false, 'error' => 'to, subject, html required']);
        exit;
    }

    $provider = tpk_text($settings['provider'] ?? '', 'SMTP');
    $message = ['to' => $to, 'subject' => $subject, 'html' => $html];

    if ($provider === 'SendGrid') {
        tpk_send_sendgrid($settings, $message);
    } elseif ($provider === 'Firebase Extension') {
        http_response_code(400);
        echo json_encode([
            'ok' => false,
            'error' => 'Firebase Extension provider is not supported by this relay. Use SMTP.',
        ]);
        exit;
    } elseif ($provider === 'Custom API') {
        throw new RuntimeException('Custom API is not supported by the PHP relay. Use SMTP or SendGrid.');
    } else {
        tpk_send_smtp($settings, $message);
    }

    echo json_encode(['ok' => true]);
} catch (Throwable $error) {
    http_response_code(500);
    echo json_encode([
        'ok' => false,
        'error' => $error->getMessage(),
    ]);
}
