<?php
require_once "resources/require.php";
require_once "resources/check_auth.php";
require_once "resources/header.php";
$document['title'] = "AI Chat Detail";
$uuid = $_GET['uuid'] ?? '';
echo "<div class='action_bar' id='action_bar'>\n";
echo "    <div class='heading'>\n";
echo "        <b><i class='fas fa-comment-dots'></i> Call Detail: #" . htmlspecialchars(substr($uuid, 0, 8)) . "</b>\n";
echo "    </div>\n";
echo "    <div class='actions'>\n";
echo "    <a href='ai_ui.php' class='btn btn-default' style='background-color: #000 !important; color: #fff !important; border: none; padding: 5px 12px; display: inline-flex; align-ite>
echo "        <span class='fas fa-arrow-left' style='color: #fff !important; margin-right: 5px;'></span> BACK\n";
echo "    </a>\n";
echo "  </div>\n";
echo "  <div style='clear: both;'></div>\n";
echo "</div>\n";
if ($uuid != '') {
    echo "<table class='list'>\n";
    echo "    <tr class='list-header'>\n";
    echo "        <th style='width: 20%;'>Time</th>\n";
    echo "        <th style='width: 15%;'>Speaker</th>\n";
    echo "        <th style='width: 65%;'>Message</th>\n";
    echo "    </tr>\n";
    $sql = "SELECT * FROM ai_logs WHERE uuid = :uuid ORDER BY created_at ASC";
    $parameters['uuid'] = $uuid;
    $database = new database;
    $chat_history = $database->select($sql, $parameters, 'all');
    if (is_array($chat_history) && @sizeof($chat_history) != 0) {
