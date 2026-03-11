<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

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

if (isset($_GET['id']) && !empty(trim($_GET['id']))) {
    $reportId = trim($_GET['id']);
    
    $stmt = $conn->prepare("SELECT reportNo, weight, species, variety, cut, dimensions, color, clarity, microscopic, gemImage, reportImage, reportPdf FROM reports WHERE reportNo = ? LIMIT 1");
    
    if ($stmt) {
        $stmt->bind_param("s", $reportId);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows > 0) {
            $row = $result->fetch_assoc();
            echo json_encode(["status" => "success", "data" => $row]);
        } else {
            echo json_encode(["status" => "error", "message" => "Report not found."]);
        }
        $stmt->close();
    } else {
        echo json_encode(["status" => "error", "message" => "Database error."]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "No report ID provided."]);
}

$conn->close();
?>