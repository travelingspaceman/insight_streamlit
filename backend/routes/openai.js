const express = require('express');
const axios = require('axios');
const router = express.Router();

const OPENAI_BASE_URL = 'https://api.openai.com/v1';

// Validate OpenAI API key
if (!process.env.OPENAI_API_KEY) {
  console.error('❌ OPENAI_API_KEY environment variable is required');
  process.exit(1);
}

// Common OpenAI request headers
const getOpenAIHeaders = () => ({
  'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
  'Content-Type': 'application/json',
});

// POST /api/openai/embeddings
// Proxy for OpenAI embeddings API
router.post('/embeddings', async (req, res) => {
  try {
    const { input } = req.body;
    
    // Validate input
    if (!input || typeof input !== 'string' || input.trim().length === 0) {
      return res.status(400).json({
        error: 'Invalid input: text is required and must be a non-empty string'
      });
    }

    // Limit input length to prevent abuse
    if (input.length > 8000) {
      return res.status(400).json({
        error: 'Input text too long. Maximum 8000 characters allowed.'
      });
    }

    const requestBody = {
      model: 'text-embedding-3-large',
      input: input.trim(),
      encoding_format: 'float'
    };

    console.log(`📊 Generating embedding for text of length: ${input.length}`);

    const response = await axios.post(
      `${OPENAI_BASE_URL}/embeddings`,
      requestBody,
      {
        headers: getOpenAIHeaders(),
        timeout: 30000 // 30 second timeout
      }
    );

    // Return the embedding data
    res.json({
      embedding: response.data.data[0].embedding,
      model: response.data.model,
      usage: response.data.usage
    });

  } catch (error) {
    console.error('OpenAI Embeddings Error:', error.response?.data || error.message);
    
    if (error.response) {
      // OpenAI API error
      const status = error.response.status;
      const message = error.response.data?.error?.message || 'OpenAI API error';
      
      res.status(status >= 400 && status < 500 ? status : 502).json({
        error: `OpenAI API error: ${message}`
      });
    } else if (error.code === 'ECONNABORTED') {
      // Timeout error
      res.status(504).json({
        error: 'Request timeout. Please try again.'
      });
    } else {
      // Network or other error
      res.status(502).json({
        error: 'Failed to connect to OpenAI API'
      });
    }
  }
});

// POST /api/openai/chat/completions
// Proxy for OpenAI chat completions API (for journal entry processing)
router.post('/chat/completions', async (req, res) => {
  try {
    const { messages, journalEntry } = req.body;
    
    // Validate input
    if (!journalEntry || typeof journalEntry !== 'string' || journalEntry.trim().length === 0) {
      return res.status(400).json({
        error: 'Invalid input: journalEntry is required and must be a non-empty string'
      });
    }

    // Limit input length
    if (journalEntry.length > 2000) {
      return res.status(400).json({
        error: 'Journal entry too long. Maximum 2000 characters allowed.'
      });
    }

    const systemPrompt = "Here is a journal entry. Provide a compassionate and uplifting response to the user based on the Teachings of the Baha'i Faith. In your response, restate what the user is saying to you.";

    const requestBody = {
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: journalEntry.trim() }
      ],
      max_tokens: 500,
      temperature: 0.7
    };

    console.log(`💭 Processing journal entry of length: ${journalEntry.length}`);

    const response = await axios.post(
      `${OPENAI_BASE_URL}/chat/completions`,
      requestBody,
      {
        headers: getOpenAIHeaders(),
        timeout: 30000
      }
    );

    // Return the processed response
    res.json({
      response: response.data.choices[0].message.content,
      usage: response.data.usage
    });

  } catch (error) {
    console.error('OpenAI Chat Error:', error.response?.data || error.message);
    
    if (error.response) {
      const status = error.response.status;
      const message = error.response.data?.error?.message || 'OpenAI API error';
      
      res.status(status >= 400 && status < 500 ? status : 502).json({
        error: `OpenAI API error: ${message}`
      });
    } else if (error.code === 'ECONNABORTED') {
      res.status(504).json({
        error: 'Request timeout. Please try again.'
      });
    } else {
      res.status(502).json({
        error: 'Failed to connect to OpenAI API'
      });
    }
  }
});

module.exports = router;