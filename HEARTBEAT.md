# Heartbeat Checklist

## Critical Rule
**NEVER reply HEARTBEAT_OK in group chats** - Only reply in direct messages.

## Checks

1. **Check if this is a group chat**
   - If `flags.has_reply_context` or `chat_type == "group"` → Reply `NO_REPLY`
   - Only proceed if direct message with +61421923133

2. **Daily maintenance**
   - Check memory files
   - Review recent changes

3. **If nothing needs attention**
   - Direct chat: `HEARTBEAT_OK`
   - Group chat: `NO_REPLY`
