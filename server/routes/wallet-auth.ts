import { RequestHandler } from "express";
import { supabase } from "../../shared/lib/supabase";

interface WalletAuthRequest {
  walletAddress: string;
}

interface WalletAuthResponse {
  success: boolean;
  message?: string;
  sessionToken?: string;
  error?: string;
}

export const handleWalletAuth: RequestHandler = async (req, res) => {
  try {
    const { walletAddress } = req.body as WalletAuthRequest;

    if (!walletAddress) {
      return res.status(400).json({
        success: false,
        error: "Wallet address is required",
      } as WalletAuthResponse);
    }

    // Generate wallet-based credentials
    const walletEmail = `wallet-${walletAddress.toLowerCase()}@wallet.local`;

    // Try to sign up first
    const { data: signUpData, error: signUpError } = await supabase.auth.signUp(
      {
        email: walletEmail,
        password: walletAddress,
      },
    );

    if (signUpError) {
      // If user already exists, sign in instead
      if (signUpError.message?.includes("already registered")) {
        const { data: signInData, error: signInError } =
          await supabase.auth.signInWithPassword({
            email: walletEmail,
            password: walletAddress,
          });

        if (signInError) {
          return res.status(401).json({
            success: false,
            error: signInError.message,
          } as WalletAuthResponse);
        }

        if (signInData.session) {
          // Create or get user profile
          const { data: profile } = await supabase
            .from("users")
            .select("*")
            .eq("auth_id", signInData.user?.id)
            .single();

          if (!profile) {
            await supabase.from("users").insert({
              auth_id: signInData.user?.id,
              email: walletEmail,
            });
          }

          return res.status(200).json({
            success: true,
            message: "Wallet connected successfully",
            sessionToken: signInData.session.access_token,
          } as WalletAuthResponse);
        }
      } else {
        return res.status(400).json({
          success: false,
          error: signUpError.message,
        } as WalletAuthResponse);
      }
    }

    if (signUpData.user && signUpData.session) {
      // Create user profile
      await supabase.from("users").insert({
        auth_id: signUpData.user.id,
        email: walletEmail,
      });

      return res.status(200).json({
        success: true,
        message: "Wallet connected successfully",
        sessionToken: signUpData.session.access_token,
      } as WalletAuthResponse);
    }

    return res.status(500).json({
      success: false,
      error: "Failed to authenticate wallet",
    } as WalletAuthResponse);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return res.status(500).json({
      success: false,
      error: message,
    } as WalletAuthResponse);
  }
};
