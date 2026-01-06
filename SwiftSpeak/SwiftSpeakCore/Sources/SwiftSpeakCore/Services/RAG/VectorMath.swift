//
//  VectorMath.swift
//  SwiftSpeakCore
//
//  Vector mathematics for similarity search
//  Uses Accelerate framework for optimized SIMD operations
//
//  SHARED: Used by iOS RAG, iOS Obsidian, and macOS Obsidian
//

import Foundation
import Accelerate

// MARK: - Vector Math

public enum VectorMath {

    /// Calculate cosine similarity between two vectors
    /// Returns a value between -1 and 1, where 1 means identical direction
    public static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        // Use Accelerate for SIMD operations on larger vectors
        if a.count >= 64 {
            vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
            vDSP_dotpr(a, 1, a, 1, &normA, vDSP_Length(a.count))
            vDSP_dotpr(b, 1, b, 1, &normB, vDSP_Length(b.count))
        } else {
            // Fallback for smaller vectors
            for i in 0..<a.count {
                dotProduct += a[i] * b[i]
                normA += a[i] * a[i]
                normB += b[i] * b[i]
            }
        }

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }

    /// Calculate Euclidean distance between two vectors
    public static func euclideanDistance(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return Float.infinity }

        var sumSquaredDiff: Float = 0

        if a.count >= 64 {
            // Use Accelerate: compute a - b, then sum of squares
            var diff = [Float](repeating: 0, count: a.count)
            vDSP_vsub(b, 1, a, 1, &diff, 1, vDSP_Length(a.count))
            vDSP_dotpr(diff, 1, diff, 1, &sumSquaredDiff, vDSP_Length(a.count))
        } else {
            for i in 0..<a.count {
                let d = a[i] - b[i]
                sumSquaredDiff += d * d
            }
        }

        return sqrt(sumSquaredDiff)
    }

    /// Normalize a vector to unit length
    public static func normalize(_ vector: [Float]) -> [Float] {
        guard !vector.isEmpty else { return vector }

        var normSquared: Float = 0
        vDSP_dotpr(vector, 1, vector, 1, &normSquared, vDSP_Length(vector.count))

        let norm = sqrt(normSquared)
        guard norm > 0 else { return vector }

        var result = [Float](repeating: 0, count: vector.count)
        var divisor = norm
        vDSP_vsdiv(vector, 1, &divisor, &result, 1, vDSP_Length(vector.count))

        return result
    }

    /// Calculate dot product of two vectors
    public static func dotProduct(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var result: Float = 0
        vDSP_dotpr(a, 1, b, 1, &result, vDSP_Length(a.count))
        return result
    }

    /// Find the magnitude (L2 norm) of a vector
    public static func magnitude(_ vector: [Float]) -> Float {
        var result: Float = 0
        vDSP_dotpr(vector, 1, vector, 1, &result, vDSP_Length(vector.count))
        return sqrt(result)
    }
}
