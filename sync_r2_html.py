import os,json,ssl,urllib.request
ctx=ssl._create_unverified_context()
w="/Users/shaliach/development/data/zehut_app/web"
f=[{"name":x,"content":open(os.path.join(w,x)).read()} for x in sorted(os.listdir(w)) if x.endswith(".html") and x!="thumb-maker.html" and os.path.getsize(os.path.join(w,x))>200]
for u in ["https://zehut-server.onrender.com/syncHtmlBatch","https://zehut-server-production.up.railway.app/syncHtmlBatch"]:
 try:
  r=urllib.request.Request(u,data=json.dumps({"files":f}).encode(),headers={"Content-Type":"application/json"},method="POST")
  print("R2 SYNC OK:",urllib.request.urlopen(r,context=ctx,timeout=30).read().decode()); break
 except Exception as e: print("Try:",u,e)
