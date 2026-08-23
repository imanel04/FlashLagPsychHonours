data {
  int<lower=0> N;                                  // number of data points
  int<lower=0> n_subjects;                         // number of subjects
  array[N] int<lower=1, upper=n_subjects> id;      // subject ID
  vector[N] y;                                     // response variable

  // Prior hyperparameters
  real pi_mean;                    // prior hyperparameter for proportion of negative true scores
  real<lower=0> pi_sd;             // (within the responder/slab subpopulation only, see note below)

  real mu_theta_mean;              // prior hyperparameter for population-level intercept
  real<lower=0> mu_theta_sd;

  real omega_mean;                   // prior hyperparameter for proportion of non-responders
  real<lower=0> omega_sd;           // Beta prior shape 2
}

parameters {
  vector[n_subjects] theta;        // subject-specific intercepts.
                                    // Meaningful only for responders; for non-responders this
                                    // is a nuisance variable whose marginal prior contributes
                                    // nothing to their likelihood term (see model block).
  real<offset=mu_theta_mean, multiplier=mu_theta_sd> mu_theta_hat;
  real<offset=pi_mean, multiplier=pi_sd> p_hat_negative_spike;
  real<lower=0> sigma_epsilon;
  real<offset=omega_mean, multiplier=omega_sd> omega_hat;    // proportion of NON-responders (spike weight)
}

transformed parameters {
  real<lower=0> sigma_theta;
  real<lower=0, upper=1> p_negative_spike;
  real mu_theta;
  real<lower=0, upper=1> omega;  // proportion of NON-responders (spike weight)
  real<lower=0, upper=1> p_negative_theta;

  p_negative_spike = Phi(p_hat_negative_spike) / 2;
  omega = p_negative_spike * Phi(omega_hat);
  p_negative_theta = p_negative_spike * (1 - Phi(omega_hat));
  mu_theta = exp(mu_theta_hat) / (1 - omega);  // population-level mean of the responder/slab subpopulation only
  sigma_theta = -mu_theta / inv_Phi(p_negative_theta);

  // Per-subject log-likelihood under each mixture component
  vector[n_subjects] lp_responder = rep_vector(0, n_subjects);
  vector[n_subjects] lp_nonresponder = rep_vector(0, n_subjects);
  for (n in 1:N) {
    lp_responder[id[n]]    += normal_lpdf(y[n] | theta[id[n]], sigma_epsilon);
    lp_nonresponder[id[n]] += normal_lpdf(y[n] | 0, sigma_epsilon);
  }
}

model {
  // Priors
  target += normal_lpdf(mu_theta_hat | mu_theta_mean, mu_theta_sd);
  target += normal_lpdf(p_hat_negative_spike | pi_mean, pi_sd);
  target += normal_lpdf(omega_hat | omega_mean, omega_sd);
  target += normal_lpdf(theta | mu_theta, sigma_theta);  // applies unconditionally; see write-up
  target += log(1 / sigma_epsilon^2);                    // Jeffreys prior on sigma_epsilon^2

  // Marginalize the discrete responder/non-responder indicator, subject by subject
  for (s in 1:n_subjects) {
    target += log_mix(1 - omega, lp_responder[s], lp_nonresponder[s]);
  }
}

generated quantities {
  vector[n_subjects] p_nonresponder;  // posterior P(subject s is a non-responder | data)

  for (s in 1:n_subjects) {
    real log_num   = log(omega) + lp_nonresponder[s];
    real log_denom = log_sum_exp(log_num, log1m(omega) + lp_responder[s]);
    p_nonresponder[s] = exp(log_num - log_denom);
  }
}
