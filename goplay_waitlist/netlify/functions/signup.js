function generateReferralCode(length = 8) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let out = '';
  for (let i = 0; i < length; i++) {
    out += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return out;
}

async function getTotalSignups(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/get_waitlist_stats`, {
    method: 'POST',
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({})
  });

  const data = await response.json();

  if (!response.ok) {
    throw new Error(`Failed to fetch stats: ${JSON.stringify(data)}`);
  }

  return Array.isArray(data) && data[0] ? Number(data[0].total_signups || 0) : 0;
}

async function emailExists(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, email) {
  const response = await fetch(
    `${SUPABASE_URL}/rest/v1/waitlist_users?select=id,email&email=eq.${encodeURIComponent(email)}`,
    {
      method: 'GET',
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
      }
    }
  );

  const data = await response.json();

  if (!response.ok) {
    throw new Error(`Failed to check email: ${JSON.stringify(data)}`);
  }

  return Array.isArray(data) && data.length > 0;
}

async function insertUser(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, payload) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/waitlist_users`, {
    method: 'POST',
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      Prefer: 'return=representation'
    },
    body: JSON.stringify(payload)
  });

  const data = await response.json();

  if (!response.ok) {
    throw new Error(`Insert failed: ${JSON.stringify(data)}`);
  }

  return data[0];
}

async function sendResendEmail({ apiKey, from, to, subject, html }) {
  if (!apiKey || !from || !to) return;

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      from,
      to,
      subject,
      html
    })
  });

  const data = await response.text();

  if (!response.ok) {
    throw new Error(`Resend failed: ${data}`);
  }
}

exports.handler = async function (event) {
  if (event.httpMethod !== 'POST') {
    return {
      statusCode: 405,
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ message: 'Method not allowed.' })
    };
  }

  try {
    const SUPABASE_URL = process.env.SUPABASE_URL;
    const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
    const RESEND_API_KEY = process.env.RESEND_API_KEY;
    const NOTIFY_EMAIL = process.env.NOTIFY_EMAIL;
    const EMAIL_FROM = process.env.EMAIL_FROM;
    const SITE_URL = process.env.SITE_URL || `https://${event.headers.host}`;

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return {
        statusCode: 500,
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ message: 'Missing Supabase environment variables.' })
      };
    }

    const body = JSON.parse(event.body || '{}');
    const name = (body.name || '').trim();
    const email = (body.email || '').trim().toLowerCase();
    const referredBy = (body.referredBy || '').trim().toUpperCase();

    if (!name || !email) {
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ message: 'Name and email are required.' })
      };
    }

    const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailPattern.test(email)) {
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ message: 'Please enter a valid email address.' })
      };
    }

    const exists = await emailExists(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, email);

    if (exists) {
      return {
        statusCode: 409,
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ message: 'That email is already on the waitlist.' })
      };
    }

    const referralCode = generateReferralCode();

    const inserted = await insertUser(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      name,
      email,
      referral_code: referralCode,
      referred_by: referredBy || null
    });

    const totalSignups = await getTotalSignups(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const referralLink = `${SITE_URL}/?ref=${encodeURIComponent(inserted.referral_code)}`;

    try {
      await sendResendEmail({
        apiKey: RESEND_API_KEY,
        from: EMAIL_FROM,
        to: NOTIFY_EMAIL,
        subject: 'New GoPlay Waitlist Signup',
        html: `
          <h2>New waitlist signup</h2>
          <p><strong>Name:</strong> ${name}</p>
          <p><strong>Email:</strong> ${email}</p>
          <p><strong>Referral Code:</strong> ${inserted.referral_code}</p>
          <p><strong>Referred By:</strong> ${referredBy || 'Direct signup'}</p>
          <p><strong>Total Signups:</strong> ${totalSignups}</p>
        `
      });

      await sendResendEmail({
        apiKey: RESEND_API_KEY,
        from: EMAIL_FROM,
        to: email,
        subject: 'You’re on the GoPlay Waitlist',
        html: `
          <h2>Welcome to GoPlay</h2>
          <p>Thanks for joining the GoPlay waitlist, ${name}.</p>
          <p>Your referral link:</p>
          <p><a href="${referralLink}">${referralLink}</a></p>
          <p>Share it with friends and move up the list.</p>
        `
      });
    } catch (emailError) {
      console.log('Email sending failed:', emailError.message || emailError);
    }

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        success: true,
        referralCode: inserted.referral_code,
        referralLink,
        position: totalSignups,
        totalSignups
      })
    };
  } catch (error) {
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        message: 'Server error creating signup.',
        error: String(error.message || error)
      })
    };
  }
};