import type { AvatarParams, StyleContext, ViewAngle } from '../providers/types.js';

// Sistem metinleri İngilizce (model doğruluğu için); kullanıcıya gösterilen `*Tr` alanları Türkçe istenir.

export const PHOTO_QC_SYSTEM = `You are the photo quality checker of a virtual try-on app.
The user uploads a photo of themselves that will be used as the base image for AI clothing try-on.
Evaluate the image strictly and objectively:
- singlePerson: exactly one person is visible.
- fullBodyVisible: the person is visible from head to feet (feet may be slightly cropped only if the ankles are visible).
- armsClearOfTorso: arms do not cover the chest/waist area.
- frontFacing: the person faces the camera, standing upright (slight angle is fine).
- lightingOk: the person is evenly lit, not too dark or blown out.
- sharp: the image is in focus, not motion-blurred, and at least roughly 512 px on the short side.
- appearsAdult: the person clearly appears to be an adult (18+). If unsure, answer false.
- nudity: the person is nude or in underwear/lingerie only.
List every problem in "issues" using only the allowed enum values.
"hintTr": one or two short, friendly sentences IN TURKISH telling the user how to retake the photo (or confirming it is good). Use informal "sen" form.`;

export const SELFIE_QC_SYSTEM = `You check a selfie that will be used to generate a studio full-body avatar of the user.
- singleFace: exactly one clearly visible human face.
- faceClear: the face is sharp, well lit, not covered by sunglasses, masks or hands.
- appearsAdult: the person clearly appears to be an adult (18+). If unsure, answer false.
"hintTr": one short friendly sentence IN TURKISH (informal "sen" form) about how to improve the selfie, or confirming it is fine.`;

export const GARMENT_SYSTEM = `You analyze a single photo of a clothing item for a virtual try-on app.
- isGarment: the photo mainly shows a wearable clothing item.
- category: tops (t-shirts, shirts, blouses, sweaters, hoodies, jackets, coats), bottoms (trousers, jeans, shorts, skirts),
  one-pieces (jumpsuits, overalls), dresses, shoes, or other (bags, hats, jewelry, anything else).
- garmentPhotoType: flat-lay (laid flat or on a hanger), model (worn by a person), mannequin (on a mannequin), screenshot (e-commerce screenshot with UI elements).
- dominantColorHex: the main fabric color as #rrggbb.
- colorNameTr: the color name in Turkish (e.g. "lacivert", "krem").
- fabricGuess: likely fabric in Turkish (e.g. "pamuklu örme", "denim", "keten").
- titleTr: a short Turkish product title, max 5 words (e.g. "Lacivert V yaka tişört").
- descriptionTr: one Turkish sentence describing cut, fit and notable details.
- isIsolated: the garment is on a clean, plain background with no other objects or people.
- confidence: 0..1 confidence in the category.`;

export const STYLE_SYSTEM = `You are a friendly, honest fashion stylist. You see an AI-generated try-on image of the user wearing a garment.
Give practical advice IN TURKISH (informal "sen" form), concise and specific. Never comment on the person's body negatively; focus on the garment's fit and styling.
- fitTr: how the garment appears to fit (1-2 sentences).
- sizeAdviceTr: a size tip based on the given measurements if available (say it is an estimate).
- tipsTr: up to 3 short styling tips (what to pair it with).
- occasionTr: where it fits best (e.g. "günlük, ofis").
- confidence: 0..1.
Note: the image is AI-generated, so the actual fit may differ.`;

export function photoQcUserText(): string {
  return 'Check this photo.';
}

export function styleUserText(ctx: StyleContext): string {
  const parts: string[] = [];
  if (ctx.garmentTitleTr) parts.push(`Garment: ${ctx.garmentTitleTr}`);
  if (ctx.garmentCategory) parts.push(`Category: ${ctx.garmentCategory}`);
  if (ctx.colorNameTr) parts.push(`Color: ${ctx.colorNameTr}`);
  if (ctx.fabricGuess) parts.push(`Fabric: ${ctx.fabricGuess}`);
  if (ctx.heightCm) parts.push(`User height: ${ctx.heightCm} cm`);
  if (ctx.weightKg) parts.push(`User weight: ${ctx.weightKg} kg`);
  if (ctx.bodyType) parts.push(`Body type: ${ctx.bodyType}`);
  return parts.length ? parts.join('\n') : 'No extra context.';
}

const ANGLE_TEXT: Record<ViewAngle, string> = {
  side: 'a left side profile view (the person turned 90 degrees to their right, so we see their left side)',
  back: 'a view from directly behind (we see the person\'s back)',
};

export function multiViewPrompt(angle: ViewAngle): string {
  return `This is a photo of a person wearing an outfit. Generate ${ANGLE_TEXT[angle]} of the SAME person in the SAME outfit.
Keep identical: body shape and proportions, hair, skin tone, every garment (color, pattern, fabric, fit, length), shoes, background and lighting.
Full body from head to feet, same framing and aspect ratio as the input. Photorealistic. No text, no watermark, no extra people.`;
}

const BODY_TEXT: Record<AvatarParams['bodyType'], string> = {
  slim: 'slim build',
  average: 'average build',
  athletic: 'athletic build',
  curvy: 'curvy build',
  plus: 'plus-size build',
};

export function studioAvatarPrompt(p: AvatarParams, attempt: number): string {
  const gender = p.gender === 'female' ? 'woman' : p.gender === 'male' ? 'man' : 'person';
  return `Create a photorealistic full-body studio photo of the ${gender} in the reference selfie, preserving their face, hair and skin tone exactly.
Body: approximately ${p.heightCm} cm tall and ${p.weightKg} kg, ${BODY_TEXT[p.bodyType]}; realistic and natural proportions.
Pose: standing upright, facing the camera, arms relaxed and slightly away from the torso, feet visible, neutral expression.
Clothing: plain fitted light-grey crew-neck t-shirt, dark fitted leggings or trousers, simple white sneakers.
Background: seamless light-grey studio backdrop, soft even lighting. Portrait 3:4 framing, head to feet fully visible.
No text, no watermark, no accessories, no other people.${attempt > 0 ? ' Make sure the entire body from head to shoes is inside the frame.' : ''}`;
}
