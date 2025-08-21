const express = require('express');
const axios = require('axios');
const router = express.Router();

// Validate Pinecone configuration
if (!process.env.PINECONE_API_KEY) {
  console.error('❌ PINECONE_API_KEY environment variable is required');
  process.exit(1);
}

const PINECONE_INDEX_NAME = process.env.PINECONE_INDEX_NAME || 'bahai-writings';
const PINECONE_ENVIRONMENT = process.env.PINECONE_ENVIRONMENT || 'us-east-1-aws';
const PINECONE_BASE_URL = `https://${PINECONE_INDEX_NAME}-${PINECONE_ENVIRONMENT}.pinecone.io`;

// Common Pinecone request headers
const getPineconeHeaders = () => ({
  'Api-Key': process.env.PINECONE_API_KEY,
  'Content-Type': 'application/json',
});

// POST /api/pinecone/search
// Proxy for Pinecone vector search
router.post('/search', async (req, res) => {
  try {
    const { vector, topK, authorFilter } = req.body;
    
    // Validate input
    if (!vector || !Array.isArray(vector) || vector.length === 0) {
      return res.status(400).json({
        error: 'Invalid input: vector is required and must be a non-empty array'
      });
    }

    // Validate vector dimensions (text-embedding-3-large uses 3072 dimensions)
    if (vector.length !== 3072) {
      return res.status(400).json({
        error: 'Invalid vector dimensions. Expected 3072 dimensions for text-embedding-3-large.'
      });
    }

    // Validate topK
    const numResults = Math.min(Math.max(parseInt(topK) || 10, 1), 50); // Between 1 and 50

    // Build filter for Pinecone
    let filter = null;
    if (authorFilter && Array.isArray(authorFilter) && authorFilter.length > 0) {
      // Filter out "All Authors" if present
      const validAuthors = authorFilter.filter(author => author !== 'All Authors');
      if (validAuthors.length > 0) {
        filter = {
          author: { "$in": validAuthors }
        };
      }
    }

    const requestBody = {
      vector: vector,
      topK: numResults,
      includeMetadata: true
    };

    // Add filter if specified
    if (filter) {
      requestBody.filter = filter;
    }

    console.log(`🔍 Searching Pinecone for ${numResults} results${filter ? ` with author filter: ${JSON.stringify(filter)}` : ''}`);

    const response = await axios.post(
      `${PINECONE_BASE_URL}/query`,
      requestBody,
      {
        headers: getPineconeHeaders(),
        timeout: 30000 // 30 second timeout
      }
    );

    // Transform the response to match iOS app expectations
    const results = response.data.matches.map(match => ({
      text: match.metadata?.text || '',
      sourceFile: match.metadata?.source_file || '',
      paragraphId: match.metadata?.paragraph_id || 0,
      score: match.score || 0,
      author: match.metadata?.author || 'Unknown'
    }));

    res.json({
      results: results,
      count: results.length
    });

  } catch (error) {
    console.error('Pinecone Search Error:', error.response?.data || error.message);
    
    if (error.response) {
      // Pinecone API error
      const status = error.response.status;
      const message = error.response.data?.message || 'Pinecone API error';
      
      res.status(status >= 400 && status < 500 ? status : 502).json({
        error: `Pinecone API error: ${message}`
      });
    } else if (error.code === 'ECONNABORTED') {
      // Timeout error
      res.status(504).json({
        error: 'Search request timeout. Please try again.'
      });
    } else {
      // Network or other error
      res.status(502).json({
        error: 'Failed to connect to Pinecone API'
      });
    }
  }
});

// GET /api/pinecone/stats
// Get index statistics
router.get('/stats', async (req, res) => {
  try {
    console.log('📊 Fetching Pinecone index statistics');

    const response = await axios.get(
      `${PINECONE_BASE_URL}/describe_index_stats`,
      {
        headers: getPineconeHeaders(),
        timeout: 10000 // 10 second timeout
      }
    );

    res.json({
      totalVectorCount: response.data.totalVectorCount || 0,
      dimension: response.data.dimension || 3072,
      indexFullness: response.data.indexFullness || 0
    });

  } catch (error) {
    console.error('Pinecone Stats Error:', error.response?.data || error.message);
    
    if (error.response) {
      const status = error.response.status;
      const message = error.response.data?.message || 'Pinecone API error';
      
      res.status(status >= 400 && status < 500 ? status : 502).json({
        error: `Pinecone API error: ${message}`
      });
    } else if (error.code === 'ECONNABORTED') {
      res.status(504).json({
        error: 'Stats request timeout. Please try again.'
      });
    } else {
      res.status(502).json({
        error: 'Failed to connect to Pinecone API'
      });
    }
  }
});

module.exports = router;