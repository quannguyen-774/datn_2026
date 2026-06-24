<?php
require_once "resources/require.php";
require_once "resources/check_auth.php";
require_once "resources/header.php";
$document['title'] = "AI Voicebot History";
echo "<div class='action_bar' id='action_bar'>\n";
echo "    <div class='heading'>\n";
echo "        <b> AI Voicebot History</b>\n";
echo "    </div>\n";
echo "    <div class='actions'>\n";
echo "    <a href='ai_ui.php' class='btn btn-default' style='background-color: #000 !important; color: #fff !important; border: none; padding: 5px 12px; display: inline-flex; align-ite>
echo "        <span class='fas fa-sync-alt' style='color: #fff !important; margin-right: 5px;'></span> Refresh\n";
echo "    </a>\n";
echo "  </div>\n";
echo "  <div style='clear: both;'></div>\n";
echo "</div>\n";
echo "<table class='list'>\n";
echo "    <tr class='list-header'>\n";
echo "        <th class='center' style='width: 50px;'>Status</th>\n";
echo "        <th>Call ID (UUID)</th>\n";
echo "        <th>Start Time</th>\n";
echo "        <th>Last Interaction</th>\n";
echo "        <th class='center'>Messages</th>\n";
echo "        <th class='action-button'>Actions</th>\n";
echo "    </tr>\n";
$sql = "SELECT uuid, MIN(created_at) as start_time, MAX(created_at) as last_time, COUNT(id) as msg_count
        FROM ai_logs
        GROUP BY uuid
        ORDER BY start_time DESC";
$database = new database;
$call_list = $database->select($sql, null, 'all');
if (is_array($call_list) && @sizeof($call_list) != 0) {
    foreach ($call_list as $row) {
        $uuid = htmlspecialchars($row['uuid'] ?? '');
        $start_time = htmlspecialchars($row['start_time'] ?? '');
        $last_time = htmlspecialchars($row['last_time'] ?? '');
        $msg_count = htmlspecialchars($row['msg_count'] ?? '0');
        $short_uuid = substr($uuid, 0, 8) . "...";
        echo "<tr class='list-row' href='ai_chat_detail.php?uuid={$uuid}'>\n";
        echo "    <td class='center'><i class='fas fa-check-circle' style='color: #2ECC71;'></i></td>\n";
        echo "    <td><a href='ai_chat_detail.php?uuid={$uuid}'>#{$short_uuid}</a></td>\n";
        echo "    <td>{$start_time}</td>\n";
        echo "    <td>{$last_time}</td>\n";
        echo "    <td class='center'><span class='badge' style='background-color: #3498DB; color: white;'>{$msg_count}</span></td>\n";
        echo "    <td class='action-button'>\n";
        echo "        <a href='ai_chat_detail.php?uuid={$uuid}' class='list-button' title='View Detail'>\n";
        echo "            <i class='fas fa-search'></i>\n";
        echo "        </a>\n";
        echo "    </td>\n";
        echo "</tr>\n";
    }
} else {
    echo "<tr class='list-row'><td colspan='6' class='center'>No AI calls recorded yet.</td></tr>\n";
}
echo "</table>\n";
require_once "resources/footer.php";
?>
