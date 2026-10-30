from pathlib import Path
p = Path(__file__).resolve().parent.parent / 'mass_changes'
p.mkdir(parents=True, exist_ok=True)
for i in range(1, 601):
    name = f'change_{i:03}.txt'
    content = f'Change file {i:03}\nGenerated for commit #{i}\n'
    (p / name).write_text(content, encoding='utf-8')
print('Generated 600 files in', p)
