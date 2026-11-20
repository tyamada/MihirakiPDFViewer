import importlib.util,json,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
s=importlib.util.spec_from_file_location('fixture',Path(__file__).with_name('prepare_sample_fixtures.py'));f=importlib.util.module_from_spec(s);s.loader.exec_module(f)
class PreparationTests(unittest.TestCase):
 def entry(self):
  d=b'%PDF-test fixture';return d,dict(episode=1,language_key='en',filename='tameshibu_episode1_3_en.pdf',bytes=len(d),sha256=f.digest(d))
 def test_legacy_alias(self):
  _,e=self.entry();self.assertIs(f.resolve([e],'tameshibu_episode1_2_en.pdf'),e)
 def test_fil_alias(self):
  _,e=self.entry();e['language_key']='fil';self.assertIs(f.resolve([e],'tameshibu_episode1_3_tl.pdf'),e)
 def test_corruption(self):
  d,e=self.entry();self.assertTrue(f.valid(d,e));self.assertFalse(f.valid(d+b'x',e));self.assertFalse(f.valid(b'x'+d[1:],e))
 def test_unknown_rejected(self):
  with self.assertRaises(ValueError):f.resolve([], '../outside.pdf')
 def run_case(self,populate):
  with tempfile.TemporaryDirectory() as td:
   p=Path(td);inp=p/'input';inp.mkdir();d,e=self.entry();mf=p/'manifest';blob=json.dumps({'entries':[e]}).encode();mf.write_bytes(blob)
   if populate:(inp/e['filename']).write_bytes(d)
   args=['prepare','--cache-dir',str(p/'cache'),'--input-dir',str(inp),'--manifest',str(mf),'--offline','--files','tameshibu_episode1_2_en.pdf']
   with patch.object(sys,'argv',args),patch.object(f,'MANIFEST_SHA256',f.digest(blob)),patch.object(f,'fetch',side_effect=AssertionError('Unexpected network')):
    if populate:
     f.main();self.assertEqual((p/'cache/tameshibu_episode1_2_en.pdf').read_bytes(),d);self.assertEqual(json.loads((p/'cache/fixture-index.json').read_text())['tameshibu_episode1_2_en.pdf']['sha256'],e['sha256'])
    else:
     with self.assertRaisesRegex(ValueError,'Missing verified offline PDF'):f.main()
     self.assertFalse((p/'cache/fixture-index.json').exists())
 def test_offline_reuse(self):self.run_case(True)
 def test_missing_is_failure(self):self.run_case(False)
 def test_in_checkout_rejected(self):
  with patch.object(sys,'argv',['prepare','--cache-dir',str(Path(f.__file__).resolve().parents[1]/'forbidden')]):
   with self.assertRaisesRegex(ValueError,'outside the checkout'):f.main()
if __name__=='__main__':unittest.main()
