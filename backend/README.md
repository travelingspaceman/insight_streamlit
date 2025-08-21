# Insight Backend API

A secure backend service that proxies API calls to OpenAI and Pinecone for the Insight iOS app, keeping API keys secure on the server.

## Features

- **Secure API Key Management**: Your OpenAI and Pinecone API keys are kept server-side
- **Rate Limiting**: Prevents abuse with configurable request limits
- **Error Handling**: Proper error responses with meaningful messages
- **Logging**: Request logging for monitoring and debugging
- **CORS Support**: Configured for iOS app requests

## API Endpoints

### OpenAI Endpoints

#### `POST /api/openai/embeddings`
Generate embeddings for search queries.

**Request Body:**
```json
{
  "input": "text to embed"
}
```

**Response:**
```json
{
  "embedding": [0.1, 0.2, ...],
  "model": "text-embedding-3-large",
  "usage": {...}
}
```

#### `POST /api/openai/chat/completions`
Process journal entries with AI guidance.

**Request Body:**
```json
{
  "journalEntry": "I'm feeling grateful today..."
}
```

**Response:**
```json
{
  "response": "AI response text",
  "usage": {...}
}
```

### Pinecone Endpoints

#### `POST /api/pinecone/search`
Search for similar passages in the Bahá'í Writings.

**Request Body:**
```json
{
  "vector": [0.1, 0.2, ...],
  "topK": 10,
  "authorFilter": ["Bahá'u'lláh", "'Abdu'l-Bahá"]
}
```

**Response:**
```json
{
  "results": [
    {
      "text": "passage text",
      "sourceFile": "hidden-words.docx",
      "paragraphId": 1,
      "score": 0.89,
      "author": "Bahá'u'lláh"
    }
  ],
  "count": 1
}
```

#### `GET /api/pinecone/stats`
Get index statistics.

**Response:**
```json
{
  "totalVectorCount": 12345,
  "dimension": 3072,
  "indexFullness": 0.5
}
```

### Health Check

#### `GET /health`
Check server status.

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "environment": "production"
}
```

## Setup

### 1. Install Dependencies

```bash
cd backend
npm install
```

### 2. Environment Configuration

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

Edit `.env` with your actual API keys:

```env
# OpenAI API Configuration
OPENAI_API_KEY=sk-your-actual-openai-key

# Pinecone API Configuration
PINECONE_API_KEY=your-actual-pinecone-key
PINECONE_INDEX_NAME=bahai-writings
PINECONE_ENVIRONMENT=us-east-1-aws

# Server Configuration
PORT=3000
NODE_ENV=production

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
```

### 3. Run the Server

**Development:**
```bash
npm run dev
```

**Production:**
```bash
npm start
```

## Deployment Options

### Option 1: Vercel (Recommended)

1. Install Vercel CLI: `npm i -g vercel`
2. Deploy: `vercel`
3. Set environment variables in Vercel dashboard
4. Update iOS app with your Vercel URL

### Option 2: Railway

1. Connect GitHub repo to Railway
2. Set environment variables in Railway dashboard
3. Deploy automatically on push

### Option 3: Render

1. Connect GitHub repo to Render
2. Configure environment variables
3. Set build command: `npm install`
4. Set start command: `npm start`

### Option 4: AWS Lambda

Use the included `serverless.yml` for AWS deployment:

```bash
npm install -g serverless
serverless deploy
```

## Security Features

- **Rate Limiting**: 100 requests per 15 minutes per IP
- **Helmet**: Security headers for protection
- **CORS**: Restricted to your app domains
- **Input Validation**: Prevents malformed requests
- **Error Sanitization**: No sensitive data in error responses

## Monitoring

The server logs:
- Request timestamps and endpoints
- Processing times
- Error details (server-side only)
- Usage patterns

For production monitoring, consider adding:
- Application Performance Monitoring (APM)
- Log aggregation (e.g., LogRocket, Sentry)
- Uptime monitoring

## Cost Management

### Rate Limiting
- Default: 100 requests per 15 minutes
- Prevents API abuse and unexpected costs
- Configurable via environment variables

### Usage Tracking
Add usage tracking to monitor:
- Number of embeddings generated
- Search queries performed
- Journal entries processed

### Optimization
- Consider caching frequent embeddings
- Implement request deduplication
- Monitor and optimize token usage

## iOS App Configuration

Update your iOS app's service URLs:

```swift
@StateObject private var openAIService = OpenAIService(
    backendBaseURL: "https://your-backend-url.com/api/openai"
)
@StateObject private var pineconeService = PineconeService(
    backendBaseURL: "https://your-backend-url.com/api/pinecone"
)
```