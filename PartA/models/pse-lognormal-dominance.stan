
data {
  int<lower=1> N;
  int<lower=1> n_subjects;
  array[N] int<lower=1, upper=n_subjects> id;
  vector[N] y;

  real mu_log_theta_mean;
  real<lower=0> mu_log_theta_sd;
  real<lower=0> sigma_log_theta_sd;
  real<lower=0> sigma_epsilon_sd;
}

parameters {
  real mu_log_theta;
  real<lower=0> sigma_log_theta;
  vector[n_subjects] z_theta;
  real<lower=0> sigma_epsilon;
}

transformed parameters {
  vector<lower=0>[n_subjects] theta;

  for (i in 1:n_subjects) {
    theta[i] = exp(mu_log_theta + sigma_log_theta * z_theta[i]);
  }
}

model {
  // Priors
  mu_log_theta ~ normal(mu_log_theta_mean, mu_log_theta_sd);

  // Proper half-normal priors
  target += normal_lpdf(sigma_log_theta | 0, sigma_log_theta_sd)
            - normal_lccdf(0 | 0, sigma_log_theta_sd);

  target += normal_lpdf(sigma_epsilon | 0, sigma_epsilon_sd)
            - normal_lccdf(0 | 0, sigma_epsilon_sd);

  // Individual differences
  z_theta ~ normal(0, 1);

  // Observation model
  y ~ normal(theta[id], sigma_epsilon);
}

generated quantities {
  real mu_theta;
  real sigma_theta;
  real p_negative_theta;
  vector[N] log_lik;

  // Mean and SD of the implied log-normal population distribution
  mu_theta = exp(mu_log_theta + 0.5 * square(sigma_log_theta));

  sigma_theta = sqrt(
    (exp(square(sigma_log_theta)) - 1)
    * exp(2 * mu_log_theta + square(sigma_log_theta))
  );

  // Under a log-normal population distribution, true negative effects are impossible
  p_negative_theta = 0;

  for (n in 1:N) {
    log_lik[n] = normal_lpdf(y[n] | theta[id[n]], sigma_epsilon);
  }
}

