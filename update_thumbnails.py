import firebase_admin
from firebase_admin import credentials, firestore

if not firebase_admin._apps:
    firebase_admin.initialize_app()

db = firestore.client()

def run():
    print("Checking Firestore 'feeds' collection...")
    docs = db.collection('feeds').stream()
    
    r2_thumb = "https://pub-142306085f2b48bda4045cd9efdd0d28.r2.dev/intro-logo.jpg"
    
    count = 0
    for doc in docs:
        data = doc.to_dict()
        current_thumb = data.get('thumb', '')
        
        if current_thumb != r2_thumb:
            db.collection('feeds').document(doc.id).update({
                'thumb': r2_thumb
            })
            print(f"Updated document ID: {doc.id} -> set thumb to R2")
            count += 1
            
    print(f"Finished! Updated {count} documents with the correct thumbnail link.")

if __name__ == '__main__':
    run()
