from pathlib import Path
import re

def check(root):
 files=[*root.glob('README*.md'),*root.glob('docs/**/*.html'),*root.glob('docs/**/*.md'),*root.glob('MihirakiPDFViewer/Models/docs/*.html'),*root.glob('MihirakiPDFViewer/Models/docs/*.md')];errors=[]
 for p in files:
  for a,b in re.findall(r'''(?:href|src)=["']([^"']+)["']|\]\(([^\s)]+)''',p.read_text()):
   if re.search(r'tameshibu[^/?#]*\.pdf(?:[?#].*)?$',a or b,re.I):errors.append(f'{p.relative_to(root)}: individual manga PDF link: {a or b}')
 return errors
if __name__=='__main__':
 errors=check(Path(__file__).resolve().parents[1])
 if errors:raise SystemExit('\n'.join(errors))
 print('User-facing manga links centralized; machine catalogs excluded.')
