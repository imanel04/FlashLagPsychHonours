
data {
  int<lower=0> N;                 // number of data points
  int<lower=0> n_subjects;        // number of subjects
  array[N] int id;                // subject ID  
  vector[N] y;                    // response variable
  
  // Hyperparameters of prior distributions on mean and sd of theta
  real mean_logN_mu;
  real <lower = 0> mean_logN_sigma;
  real sd_logN_mu;
  real <lower = 0> sd_logN_sigma;
}

parameters {
  real <offset = mean_logN_mu, multiplier = mean_logN_sigma> mean_logN_hat;
  real <offset = sd_logN_mu, multiplier = sd_logN_sigma> sd_logN_hat;
  
  vector [n_subjects] theta_hat;                                          // placerholder for log-normal subject-specific intercepts
  real<lower=0> sigma_epsilon;                                            // standard deviation of the response variable
}

transformed parameters {
  real <lower = 0> mean_logN = exp(mean_logN_hat);            // prior log normal distributed
  real <lower = 0> sd_logN = exp(sd_logN_hat);                // prior log normal distributed
  
  real mu_theta = log( (mean_logN^2) / (sqrt(sd_logN^2 + mean_logN^2)) );   // transforming mean and sd into model parameters
  real <lower = 0> sigma_theta = log( (sd_logN^2)/(mean_logN^2) + 1 );
  
  vector [n_subjects] theta = exp(theta_hat);           // model assumes log-normal distributed theta
}


model {
  // Priors
  target += normal_lpdf(sd_logN_hat | sd_logN_mu, sd_logN_sigma);
  target += normal_lpdf(mean_logN_hat | mean_logN_mu, mean_logN_sigma);  
  
  target += normal_lpdf(theta_hat | mu_theta, sigma_theta);
  target += log(1/sigma_epsilon^2);                    // Jeffreys prior on sigma2
  
  // Likelihood
  target += normal_lpdf(y | theta[id], sigma_epsilon);
}

