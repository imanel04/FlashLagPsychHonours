data {
  int<lower=0> N;                 // number of data points
  int<lower=0> n_subjects;        // number of subjects
  int id[N];                      // subject ID  
  vector[N] y;                    // response variable

  // Prior hyperparameters
  real pi_mean;         // prior hyperparameter for proportion of negative true scores
  real<lower=0> pi_sd;          // prior hyperparameter for proportion of negative true scores

  real mu_theta_mean;            // prior hyperparameter for population-level intercept
  real<lower=0> mu_theta_sd;     // prior hyperparameter for population-level
}

transformed data {
  int n_trials = N / n_subjects;  // number of data points
}

parameters {
  vector[n_subjects] theta;       // subject-specific intercepts
  real<offset=mu_theta_mean,multiplier=mu_theta_sd> mu_theta_hat;                  // population-level intercept
  real<offset=pi_mean,multiplier=pi_sd> p_hat_negative_theta;              // unconstrained parameter for proportion of negative true scores
  real<lower=0> sigma_epsilon;    // standard deviation of the response variable
}

transformed parameters {
  real<lower=0> sigma_theta;      // standard deviation of subject intercepts
  real<lower=0, upper=1> p_negative_theta;      // proportion of negative true scores
  real mu_theta = exp(mu_theta_hat);
  
  p_negative_theta = Phi(p_hat_negative_theta) / 2; // transform unconstrained parameter to positive scale
  sigma_theta = -mu_theta / inv_Phi(p_negative_theta); // derive sigma_theta from mu_theta and pi
}

model {
  // Priors
  target += normal_lpdf(mu_theta_hat | mu_theta_mean, mu_theta_sd);
  target += normal_lpdf(p_hat_negative_theta | pi_mean, pi_sd);
  target += normal_lpdf(theta | mu_theta, sigma_theta);

  target += log(1/sigma_epsilon^2); // Jeffreys prior on sigma2

  // Likelihood
  target += normal_lpdf(y | theta[id], sigma_epsilon);
}
