import { motion } from "framer-motion";

export default function MoneyFlow() {
  return (
    <section className="py-24 bg-white">
      <div className="max-w-3xl mx-auto px-6 text-center">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
        >
          <h2 className="font-heading text-2xl md:text-3xl font-bold text-foreground mb-8">
            Where Your Money Goes
          </h2>
          
          {/* Horizontal Stacked Bar */}
          <div className="h-4 md:h-6 w-full rounded-full overflow-hidden flex mb-6 shadow-inner">
            <motion.div 
              initial={{ width: 0 }}
              whileInView={{ width: "85%" }}
              transition={{ duration: 1, delay: 0.2, ease: "easeOut" }}
              className="h-full bg-primary" 
              title="85% Programs & Services" 
            />
            <motion.div 
              initial={{ width: 0 }}
              whileInView={{ width: "10%" }}
              transition={{ duration: 1, delay: 0.4, ease: "easeOut" }}
              className="h-full bg-yellow-500" 
              title="10% Operations" 
            />
            <motion.div 
              initial={{ width: 0 }}
              whileInView={{ width: "5%" }}
              transition={{ duration: 1, delay: 0.6, ease: "easeOut" }}
              className="h-full bg-muted-foreground/30" 
              title="5% Administration" 
            />
          </div>

          <div className="flex flex-wrap justify-center gap-6 mb-10">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-primary" />
              <span className="font-body text-sm font-medium text-foreground">85% Programs & Services</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-yellow-500" />
              <span className="font-body text-sm font-medium text-foreground">10% Operations</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-muted-foreground/30" />
              <span className="font-body text-sm font-medium text-foreground">5% Administration</span>
            </div>
          </div>

        </motion.div>
      </div>
    </section>
  );
}
