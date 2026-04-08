import { motion, useInView, animate } from "framer-motion";
import { useEffect, useRef, useState } from "react";

<<<<<<< data_updates
export type ImpactStatsData = {
  girlsServed: string;
  safehouses: string;
  reintegration: string;
};

const defaultStats: ImpactStatsData = {
  girlsServed: "250+",
  safehouses: "5",
  reintegration: "87%",
};

function ImpactStatCard({
  icon: Icon,
  label,
  description,
  displayValue,
  motionDelay = 0,
}: {
  icon: LucideIcon;
=======
interface Stat {
  value: number;
  suffix: string;
>>>>>>> main
  label: string;
  description: string;
  displayValue: string;
  motionDelay?: number;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ delay: motionDelay, duration: 0.5 }}
      className="relative bg-card rounded-2xl border border-border p-8 text-center group hover:shadow-lg hover:border-primary/20 transition-all duration-300"
    >
      <div className="inline-flex items-center justify-center w-14 h-14 rounded-xl bg-primary/10 text-primary mb-5 group-hover:bg-primary group-hover:text-primary-foreground transition-colors duration-300">
        <Icon className="h-6 w-6" />
      </div>
      <div className="font-heading text-4xl md:text-5xl font-bold text-foreground mb-2 min-h-[3rem] flex items-center justify-center">
        {displayValue}
      </div>
      <div className="font-body text-base font-semibold text-foreground mb-2">{label}</div>
      <p className="font-body text-sm text-muted-foreground leading-relaxed">{description}</p>
    </motion.div>
  );
}

<<<<<<< data_updates
function GirlsServedStat({ value }: { value: string }) {
  return (
    <ImpactStatCard
      icon={Users}
      label="Girls Served"
      description="Survivors given safety and support since 2018"
      displayValue={value}
      motionDelay={0}
    />
  );
}

function SafehousesStat({ value }: { value: string }) {
  return (
    <ImpactStatCard
      icon={Home}
      label="Safehouses"
      description="Operating across the Philippines with local partners"
      displayValue={value}
      motionDelay={0.15}
    />
  );
}

function ReintegrationStat({ value }: { value: string }) {
  return (
    <ImpactStatCard
      icon={TrendingUp}
      label="Reintegration Rate"
      description="Successfully reintegrated into safe communities"
      displayValue={value}
      motionDelay={0.3}
    />
  );
}

export default function ImpactStats({ stats = defaultStats }: { stats?: ImpactStatsData }) {
=======
const stats: Stat[] = [
  {
    value: 250,
    suffix: "+",
    label: "Survivors Empowered",
    description: "Survivors given safety and support since 2018",
  },
  {
    value: 5,
    suffix: "",
    label: "Safehouses",
    description: "Operating across the Philippines with local partners",
  },
  {
    value: 87,
    suffix: "%",
    label: "Reintegration Rate",
    description: "Successfully reintegrated into safe communities",
  },
];

function AnimatedCounter({ value, suffix }: { value: number; suffix: string }) {
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true, margin: "-50px" });
  const [count, setCount] = useState(0);

  useEffect(() => {
    if (isInView) {
      const controls = animate(0, value, {
        duration: 2.5,
        ease: "easeOut",
        onUpdate(v) {
          setCount(Math.floor(v));
        },
      });
      return () => controls.stop();
    }
  }, [value, isInView]);

  return (
    <span ref={ref}>
      {count}
      {suffix}
    </span>
  );
}

export default function ImpactStats() {
>>>>>>> main
  return (
    <section id="impact" className="py-24 bg-[#FDFBF7]">
      <div className="max-w-7xl mx-auto px-6">
        <div className="text-center mb-16">
          <span className="inline-block px-4 py-1.5 rounded-full bg-primary/10 text-primary text-xs font-body font-semibold tracking-widest uppercase mb-4">
            Our Impact
          </span>
          <h2 className="font-heading text-3xl md:text-4xl font-bold text-foreground">
            Measurable Change, Real Lives
          </h2>
        </div>
<<<<<<< data_updates

        <div className="grid md:grid-cols-3 gap-8">
          <GirlsServedStat value={stats.girlsServed} />
          <SafehousesStat value={stats.safehouses} />
          <ReintegrationStat value={stats.reintegration} />
=======
        <div className="grid md:grid-cols-3 gap-12">
          {stats.map((stat, i) => (
            <motion.div
              key={stat.label}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.15, duration: 0.6, ease: "easeOut" }}
              className="relative p-6 text-center"
            >
              <div className="font-heading text-6xl md:text-7xl font-bold text-primary mb-4 drop-shadow-sm">
                <AnimatedCounter value={stat.value} suffix={stat.suffix} />
              </div>
              <div className="font-body text-lg font-semibold text-foreground mb-2">
                {stat.label}
              </div>
              <p className="font-body text-base text-muted-foreground leading-relaxed">
                {stat.description}
              </p>
            </motion.div>
          ))}
>>>>>>> main
        </div>
      </div>
    </section>
  );
}
