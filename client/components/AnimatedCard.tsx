import { motion } from "framer-motion";
import { forwardRef, HTMLAttributes } from "react";

interface AnimatedCardProps extends HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode;
  interactive?: boolean;
}

const AnimatedCard = forwardRef<HTMLDivElement, AnimatedCardProps>(
  ({ children, interactive = true, className = "", ...props }, ref) => {
    return (
      <motion.div
        ref={ref}
        initial={{ opacity: 0, y: 20 }}
        whileInView={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        viewport={{ once: true }}
        whileHover={interactive ? { y: -5, boxShadow: "0 20px 25px -5px rgba(0, 0, 0, 0.1)" } : {}}
        whileTap={interactive ? { scale: 0.98 } : {}}
        className={className}
        {...props}
      >
        {children}
      </motion.div>
    );
  },
);

AnimatedCard.displayName = "AnimatedCard";

export { AnimatedCard };
