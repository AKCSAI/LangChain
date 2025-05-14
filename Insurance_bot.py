# Required pip installations:
# pip install langchain faiss-cpu unstructured chromadb flask ollama

from langchain.vectorstores import FAISS
from langchain.embeddings import OllamaEmbeddings
from langchain.document_loaders import UnstructuredFileLoader
from langchain.llms import Ollama
from langchain.chains import RetrievalQA
from flask import Flask, request, jsonify
import os

# Step 1: Load and chunk your insurance data
loader = UnstructuredFileLoader("data/insurance_faq.txt")  # Put your source file here
docs = loader.load()

# Step 2: Create embeddings and vector store
embeddings = OllamaEmbeddings(model="nomic-embed-text")  # Use an embedding model supported by Ollama
vectorstore = FAISS.from_documents(docs, embeddings)

# Step 3: Initialize the Ollama LLM
llm = Ollama(model="llama3")  # Or any other Ollama-supported model

# Step 4: Set up the RAG chain
qa = RetrievalQA.from_chain_type(llm=llm, retriever=vectorstore.as_retriever())

# Step 5: Create a simple Flask API
app = Flask(__name__)

@app.route("/ask", methods=["POST"])
def ask():
    question = request.json.get("question", "")
    answer = qa.run(question)
    return jsonify({"answer": answer})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
