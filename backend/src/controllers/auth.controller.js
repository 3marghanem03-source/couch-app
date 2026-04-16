const { z } = require('zod');
const { admin, db } = require('../db/firestore');

const roleSchema = z.enum(['coach', 'client']);

const signupSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
  role: roleSchema,
  displayName: z.string().min(1).optional(),
});

async function signup(req, res) {
  const body = signupSchema.parse(req.body);

  const displayName = body.displayName || '';

  try {
    // Create Firebase Auth user (email/password handled by Firebase).
    const userRecord = await admin.auth().createUser({
      email: body.email,
      password: body.password,
      displayName,
    });

    // Set custom claim for role.
    await admin.auth().setCustomUserClaims(userRecord.uid, { role: body.role });

    await db.collection('users').doc(userRecord.uid).set({
      uid: userRecord.uid,
      role: body.role,
      displayName,
      email: body.email,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(201).json({ uid: userRecord.uid, role: body.role });
  } catch (err) {
    // Surface actionable Firebase Admin/Auth misconfiguration errors.
    const code = err?.errorInfo?.code || err?.code;
    const message = err?.errorInfo?.message || err?.message || 'Signup failed';

    // Common when Firebase Authentication isn't enabled for the project.
    if (
      code === 'auth/configuration-not-found' ||
      /no configuration corresponding to the provided identifier/i.test(message)
    ) {
      return res.status(500).json({
        error:
          'Firebase Auth is not configured for this project. In Firebase Console: Authentication → Get started, then enable Email/Password provider.',
        details: { code, message },
      });
    }

    if (code === 'auth/email-already-exists') {
      return res.status(409).json({
        error: 'This email is already registered. Try Login instead.',
        details: { code, message },
      });
    }

    if (code === 'auth/invalid-email') {
      return res.status(400).json({
        error: 'That email address is invalid.',
        details: { code, message },
      });
    }

    if (code === 'auth/invalid-password' || code === 'auth/weak-password') {
      return res.status(400).json({
        error: 'Password is too weak. Use at least 6 characters.',
        details: { code, message },
      });
    }

    return res.status(500).json({ error: message, details: { code } });
  }
}

function me(req, res) {
  return res.json({ user: req.user });
}

module.exports = { signup, me };

