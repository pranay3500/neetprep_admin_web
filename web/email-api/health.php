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
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

echo json_encode([
    'ok' => true,
    'service' => 'neetprep-admin-email-relay',
    'runtime' => 'php',
]);
