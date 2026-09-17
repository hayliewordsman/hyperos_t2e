package dev.titan2e.shadercheck

import android.app.Activity
import android.graphics.*
import android.os.Bundle
import android.view.View
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * Compiles the Facet AGSL shaders and draws them.
 *
 * The point is the constructor: RuntimeShader compiles its source immediately
 * and throws on a syntax or type error. So merely constructing both shaders
 * validates the one thing that a full ROM build would otherwise be needed to
 * check -- and this runs on any Android 13+ device or emulator instead of
 * needing a 300 GB source tree.
 *
 * The AGSL below is copied verbatim from patches/systemui/. Run
 * tools/shader-check/verify-sync.sh to confirm it has not drifted.
 */
class MainActivity : Activity() {

    companion object {
        const val EDGE_SHADER = """
            uniform vec2 in_size;
            uniform float in_thickness;
            uniform float in_intensity;
            uniform vec3 in_tint;
        
            vec4 main(vec2 p) {
                float t = max(in_thickness, 1.0);

                // Falloff from the top edge. Squared so the band stays tight at
                // its peak and fades quickly, rather than smearing down the panel.
                float d = p.y / t;
                float edge = exp(-d * d * 2.0);

                // Bias toward the centre, so the highlight reads as a curved
                // surface catching light rather than a painted-on stripe.
                float x = (p.x / max(in_size.x, 1.0)) * 2.0 - 1.0;
                float arc = max(1.0 - x * x * 0.55, 0.0);

                float a = clamp(edge * arc * in_intensity, 0.0, 1.0);

                // AGSL expects premultiplied alpha.
                return vec4(in_tint * a, a);
            }
        """
        const val RIM_SHADER = """
            uniform shader in_src;
            uniform vec2 in_size;
            uniform float in_rim;
            uniform float in_amount;
        
            vec4 main(vec2 p) {
                float r = max(in_rim, 1.0);

                float dl = p.x / r;
                float dr = (in_size.x - p.x) / r;

                // Peaks at both vertical edges and falls to nothing across the
                // middle, so the panel darkens at its rims only.
                float band = abs(exp(-dl * dl) - exp(-dr * dr));

                vec4 c = in_src.eval(p);

                // Colour is premultiplied, so scaling rgb darkens without
                // altering coverage. Alpha is deliberately left untouched.
                return vec4(c.rgb * (1.0 - in_amount * band), c.a);
            }
        """
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val log = StringBuilder()
        var edge: RuntimeShader? = null
        var rim: RuntimeShader? = null

        try {
            edge = RuntimeShader(EDGE_SHADER)
            log.append("FacetEdgeShader: COMPILED\n")
        } catch (t: Throwable) {
            log.append("FacetEdgeShader: FAILED\n").append(t.message).append("\n\n")
        }

        try {
            rim = RuntimeShader(RIM_SHADER)
            log.append("FacetRimShader: COMPILED\n")
        } catch (t: Throwable) {
            log.append("FacetRimShader: FAILED\n").append(t.message).append("\n\n")
        }

        val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(TextView(this).apply {
            text = log.toString()
            textSize = 13f
            setPadding(24, 24, 24, 24)
            typeface = Typeface.MONOSPACE
        })
        root.addView(ShaderView(this, edge, rim), LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.MATCH_PARENT))
        setContentView(ScrollView(this).apply { addView(root) })
    }
}

/** Draws each shader that compiled, so the output can be eyeballed. */
private class ShaderView(
    context: android.content.Context,
    private val edge: RuntimeShader?,
    private val rim: RuntimeShader?,
) : View(context) {

    private val paint = Paint()

    /** A striped backdrop, so the rim shader has something to sample. */
    private fun backdrop(w: Int, h: Int): Bitmap {
        val bmp = Bitmap.createBitmap(maxOf(w, 1), maxOf(h, 1), Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val p = Paint()
        for (x in 0 until bmp.width step 40) {
            p.color = if ((x / 40) % 2 == 0) Color.rgb(70, 90, 180) else Color.rgb(150, 80, 160)
            c.drawRect(x.toFloat(), 0f, (x + 40).toFloat(), bmp.height.toFloat(), p)
        }
        return bmp
    }

    override fun onDraw(canvas: Canvas) {
        val w = width
        val half = height / 2
        if (w <= 0 || half <= 0) return

        val bmp = backdrop(w, half)
        val src = BitmapShader(bmp, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)

        // Top half: the edge highlight over the backdrop.
        canvas.drawBitmap(bmp, 0f, 0f, null)
        edge?.let {
            it.setFloatUniform("in_size", w.toFloat(), half.toFloat())
            it.setFloatUniform("in_thickness", 36f)
            it.setFloatUniform("in_intensity", 0.8f)
            it.setFloatUniform("in_tint", 1f, 1f, 1f)
            paint.shader = it
            canvas.drawRect(0f, 0f, w.toFloat(), half.toFloat(), paint)
        }

        // Bottom half: the rim darkening, sampling the backdrop.
        canvas.save()
        canvas.translate(0f, half.toFloat())
        rim?.let {
            it.setInputShader("in_src", src)
            it.setFloatUniform("in_size", w.toFloat(), half.toFloat())
            it.setFloatUniform("in_rim", 140f)
            it.setFloatUniform("in_amount", 0.6f)
            paint.shader = it
            canvas.drawRect(0f, 0f, w.toFloat(), half.toFloat(), paint)
        } ?: canvas.drawBitmap(bmp, 0f, 0f, null)
        canvas.restore()
    }
}
