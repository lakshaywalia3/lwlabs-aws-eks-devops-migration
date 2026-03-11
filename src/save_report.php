<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') { exit(0); }

// Production Standard: Fetching credentials from K8s Environment Variables
$servername = getenv('DB_HOST') ?: "localhost";
$username = getenv('DB_USER') ?: "root";
$password = getenv('DB_PASS') ?: "";
$dbname = getenv('DB_NAME') ?: "lwlabs_report";

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    echo json_encode(["status" => "error", "message" => "Database connection failed."]);
    exit();
}

$data = json_decode(file_get_contents("php://input"));

if (isset($data->reportNo)) {
    $clarity = isset($data->clarity) ? $data->clarity : "";
    $reportPdf = isset($data->reportPdf) ? $data->reportPdf : "";

    $stmt = $conn->prepare("INSERT INTO reports (reportNo, weight, species, variety, cut, dimensions, color, clarity, microscopic, gemImage, reportImage, reportPdf) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE weight=VALUES(weight), species=VALUES(species), variety=VALUES(variety), cut=VALUES(cut), dimensions=VALUES(dimensions), color=VALUES(color), clarity=VALUES(clarity), microscopic=VALUES(microscopic), gemImage=VALUES(gemImage), reportImage=VALUES(reportImage), reportPdf=VALUES(reportPdf)");
    
    $stmt->bind_param("ssssssssssss", 
        $data->reportNo, $data->weight, $data->species, $data->variety, 
        $data->cut, $data->dimensions, $data->color, $clarity, 
        $data->microscopic, $data->gemImage, $data->reportImage, $reportPdf
    );

    if ($stmt->execute()) {
        echo json_encode(["status" => "success", "message" => "Report saved successfully."]);
    } else {
        echo json_encode(["status" => "error", "message" => "Failed to save to database: " . $stmt->error]);
    }
    $stmt->close();
} else {
    echo json_encode(["status" => "error", "message" => "Invalid data received."]);
}

$conn->close();
?>