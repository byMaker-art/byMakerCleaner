import json
import sys

CONVERSATION_ID = '25773c32-85f5-4ea3-a0b4-838d6640fca9'
transcript_path = f'/Users/bymaker/.gemini/antigravity-ide/brain/{CONVERSATION_ID}/.system_generated/logs/transcript_full.jsonl'
output_path = '/Users/bymaker/Documents/GitHub/byMakerCleaner/md/log-07.md'

output = "# Лог диалога — byMakerCleaner (Session 07)\n\n"
output += f"> Conversation ID: `{CONVERSATION_ID}`\n\n---\n\n"

step_count = 0

with open(transcript_path, 'r', encoding='utf-8') as f:
    for line in f:
        try:
            data = json.loads(line)
        except:
            continue

        step_type = data.get('type')
        step_index = data.get('step_index', '')

        if step_type == 'USER_INPUT':
            content = data.get('content', '').strip()
            if not content:
                continue
            step_count += 1
            output += f"## 🧑‍💻 User (Step {step_index})\n\n{content}\n\n---\n\n"

        elif step_type == 'PLANNER_RESPONSE':
            thought = data.get('thinking', '').strip()
            content = data.get('content', '').strip()

            if not content and not thought:
                continue

            step_count += 1
            if thought:
                # Truncate very long thinking sections
                if len(thought) > 2000:
                    thought = thought[:2000] + '\n\n[... truncated ...]'
                output += f"## 🤖 AI Thought (Step {step_index})\n\n```\n{thought}\n```\n\n"

            if content:
                # Truncate extremely long responses
                if len(content) > 8000:
                    content = content[:8000] + '\n\n[... truncated ...]'
                output += f"## 🤖 AI Response (Step {step_index})\n\n{content}\n\n---\n\n"

output += f"\n---\n\n_Total steps logged: {step_count}_\n"

with open(output_path, 'w', encoding='utf-8') as f:
    f.write(output)

print(f'Log generated: {output_path}')
print(f'Total steps: {step_count}')
